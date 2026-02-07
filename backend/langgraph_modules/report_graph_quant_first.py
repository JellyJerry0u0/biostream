"""
LangGraph 기반 리포트 생성 워크플로우 (Quant-First 아키텍처)
정량 근거를 먼저 확보하고, 그를 중심으로 서술을 생성하는 구조

노드 흐름:
1. LoadSurvey
2. PlanSections
3. PreloadQuantEvidence (신규: 정량 근거 먼저 확보)
4. BuildQueries (quant 결과 반영)
5. RetrieveNarrativeEvidence (원문 검색)
6. WriteSectionCards (4카드 JSON 생성)
7. AssembleReport (카드 기반 리포트 조립)
8. SaveReport
"""

import os
import json
import sys
import re
import math
from typing import Dict, Any, List, Optional, TypedDict
from collections import defaultdict
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage, SystemMessage
import google.generativeai as genai

# 패키지 langgraph import
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

# Tools import
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(backend_dir)
from tools.survey_tool import get_survey
from tools.qdrant_search import qdrant_search
from tools.report_store import save_report
from tools.schemas import QdrantSearchInput, EvidenceItem

# 정량 근거 검색 모듈 import
services_dir = os.path.join(backend_dir, "app", "services")
if services_dir not in sys.path:
    sys.path.append(services_dir)
from quant_evidence_retriever import (
    search_by_outcomes, get_grouped_stats, get_grouped_stats_multi,
    QuantEvidenceCard
)

# Google API Key 설정
GOOGLE_API_KEY = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY") or ""
if not GOOGLE_API_KEY:
    print("⚠️ 경고: GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")

# LLM 초기화
llm = None
genai_model_name = None
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    models_to_try = [
        "gemini-2.5-flash",
        "gemini-2.0-flash",
        "gemini-pro-latest",
        "gemini-flash-latest",
    ]
    for model_name in models_to_try:
        try:
            model = genai.GenerativeModel(model_name)
            genai_model_name = model_name
            llm = ChatGoogleGenerativeAI(
                model=model_name,
                temperature=0.7,
                google_api_key=GOOGLE_API_KEY,
                max_retries=3,
            )
            print(f"✅ LLM 초기화 성공 - 모델: {model_name}")
            break
        except Exception as e:
            print(f"⚠️ 모델 {model_name} 초기화 실패: {e}")
            continue


def extract_json_from_text(text: str) -> Optional[Dict[str, Any]]:
    """LLM 응답에서 JSON만 추출"""
    # ```json 블록 찾기
    json_match = re.search(r'```json\s*\n(.*?)\n```', text, re.DOTALL)
    if json_match:
        text = json_match.group(1)
    else:
        # ``` 블록 찾기
        json_match = re.search(r'```\s*\n(.*?)\n```', text, re.DOTALL)
        if json_match:
            text = json_match.group(1)
        else:
            # { } 블록 찾기
            json_match = re.search(r'\{.*\}', text, re.DOTALL)
            if json_match:
                text = json_match.group(0)
    
    try:
        return json.loads(text.strip())
    except json.JSONDecodeError:
        # 앞뒤 불필요한 텍스트 제거 후 재시도
        text = re.sub(r'^[^{]*', '', text)
        text = re.sub(r'[^}]*$', '', text)
        try:
            return json.loads(text.strip())
        except json.JSONDecodeError:
            return None


def invoke_llm_json(prompt: str, system_prompt: str = "") -> Optional[Dict[str, Any]]:
    """LLM 호출하여 JSON 응답 파싱"""
    if not GOOGLE_API_KEY:
        return None
    
    try:
        raw_text = ""
        if llm:
            messages = []
            if system_prompt:
                messages.append(SystemMessage(content=system_prompt))
            messages.append(HumanMessage(content=prompt))
            response = llm.invoke(messages)
            raw_text = response.content if hasattr(response, 'content') else str(response)
        else:
            if not genai_model_name:
                genai_model_name = "gemini-2.5-flash"
            model = genai.GenerativeModel(genai_model_name)
            full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
            response = model.generate_content(full_prompt)
            raw_text = response.text
        
        return extract_json_from_text(raw_text)
    except Exception as e:
        print(f"⚠️ LLM 호출 실패: {e}")
        return None


# State 정의
class ReportState(TypedDict):
    """리포트 생성 상태 (Quant-First)"""
    user_id: int
    lifestyle_id: Optional[int]
    survey: Optional[Dict[str, Any]]
    active_sections: List[str]
    quant_evidence_results: Dict[str, Dict[str, Any]]  # section -> {mode, selected_outcomes, stats_by_outcome, quant_refs}
    section_queries: Dict[str, str]
    narrative_evidence: Dict[str, List[EvidenceItem]]  # 섹션별 원문 근거
    section_cards: Dict[str, List[Dict[str, Any]]]  # 섹션별 4카드 JSON
    final_report: Optional[Dict[str, Any]]


# 목표 한글 매핑
OUTCOME_LABELS = {
    "wrinkle": "주름",
    "elasticity": "탄력",
    "pigmentation": "색소",
    "hydration": "수분",
    "hydration_barrier": "장벽",
    "acne": "여드름",
    "redness": "홍조",
    "general_aging": "전체 노화",
    "general_skin": "전체 피부",
}

# outcome polarity
OUTCOME_POLARITY = {
    "wrinkle": "decrease_is_improvement",
    "elasticity": "increase_is_improvement",
    "pigmentation": "decrease_is_improvement",
    "hydration": "increase_is_improvement",
    "hydration_barrier": "increase_is_improvement",
    "acne": "decrease_is_improvement",
    "redness": "decrease_is_improvement",
    "general_aging": "mixed",
    "general_skin": "mixed",
}

# UI outcomes → quant_evidence.outcome_mapped 매핑
UI_OUTCOME_TO_QUANT_MAPPED = {
    "wrinkle": ["wrinkle", "elasticity"],
    "elasticity": ["elasticity", "wrinkle"],
    "hydration": ["hydration_barrier"],
    "hydration_barrier": ["hydration_barrier"],
    "pigmentation": ["pigmentation"],
    "acne": ["acne"],
    "redness": ["redness"],
    "general_aging": ["general_skin", "wrinkle", "elasticity", "pigmentation"],
}

# 섹션별 outcome 후보 리스트 (우선순위 순)
SECTION_OUTCOME_CANDIDATES = {
    "sleep": ["hydration_barrier", "wrinkle", "elasticity", "redness"],
    "uv": ["pigmentation", "wrinkle", "elasticity", "redness"],
    "lifestyle": ["acne", "redness", "hydration_barrier", "pigmentation"],
    "activity": ["elasticity", "wrinkle", "general_skin"],
}

# 표준 timeframe (일 단위)
STANDARD_TIMEFRAMES = {
    "4w": 28.0,
    "12w": 84.0,
    "6m": 182.5,
}


def timeframe_days_to_label(days: float) -> str:
    """timeframe_days를 사람이 읽기 쉬운 레이블로 변환"""
    if days <= 35:
        return "4주"
    elif days <= 100:
        return "12주"
    elif days <= 200:
        return "6개월"
    else:
        weeks = round(days / 7)
        return f"{weeks}주"


def calculate_estimated_stats(outcome_list: List[str]) -> Optional[Dict[str, Any]]:
    """전체 코퍼스에서 추정치 계산 (fallback)"""
    try:
        stats = get_grouped_stats_multi(outcome_list, exclude_suspicious=True)
        if not stats or not stats.get("timeframe_groups"):
            return None
        
        # 표준 timeframe 중 존재하는 것 선택
        timeframe_groups = stats["timeframe_groups"]
        selected_timeframe = None
        for tf_label, tf_days in STANDARD_TIMEFRAMES.items():
            # 가장 가까운 timeframe 찾기
            for days in timeframe_groups.keys():
                if abs(days - tf_days) < 7:  # 7일 이내 차이면 같은 것으로 간주
                    selected_timeframe = days
                    break
            if selected_timeframe:
                break
        
        if not selected_timeframe:
            # 가장 많은 카드를 가진 timeframe 선택
            selected_timeframe = max(timeframe_groups.keys(), key=lambda d: len(timeframe_groups[d]))
        
        group = timeframe_groups[selected_timeframe]
        median = abs(group["median"])
        
        # 극단치 클리핑 (>50%는 제외)
        if median > 50:
            return None
        
        # 보수적 범위 계산
        min_val = max(group["min"], -30)  # -30% 이하는 제외
        max_val = min(group["max"], 30)   # 30% 이상은 제외
        
        return {
            "timeframe_days": selected_timeframe,
            "timeframe_label": timeframe_days_to_label(selected_timeframe),
            "median": median,
            "min": min_val,
            "max": max_val,
            "count": group["count"],
        }
    except Exception as e:
        print(f"  ⚠️ 추정치 계산 실패: {e}")
        return None


# 노드 1: LoadSurvey
def load_survey(state: ReportState) -> ReportState:
    """설문 데이터 로드"""
    user_id = state["user_id"]
    lifestyle_id = state.get("lifestyle_id")
    
    print(f"[LoadSurvey] user_id={user_id}, lifestyle_id={lifestyle_id}")
    
    try:
        survey = get_survey(user_id, lifestyle_id=lifestyle_id)
        if "error" in survey:
            print(f"⚠️ [LoadSurvey] 오류: {survey['error']}")
            return {**state, "survey": None}
        print(f"✅ [LoadSurvey] 설문 데이터 로드 완료")
        return {**state, "survey": survey}
    except Exception as e:
        print(f"❌ [LoadSurvey] 실패: {e}")
        return {**state, "survey": None}


# 노드 2: PlanSections
def plan_sections(state: ReportState) -> ReportState:
    """생성할 섹션 계획"""
    print("[PlanSections] 섹션 계획 시작")
    survey = state.get("survey")
    if not survey:
        return {**state, "active_sections": []}
    
    sections = ["goals"]  # goals는 항상 포함
    
    if survey.get("sleep_hours_weekday") is not None or survey.get("sleep_quality_score") is not None:
        sections.append("sleep")
    if survey.get("uv_exposure_10to16") or survey.get("sunscreen_frequency"):
        sections.append("uv")
    if survey.get("drinking_days_per_week") or survey.get("smoking_status") or survey.get("stress_score"):
        sections.append("lifestyle")
    if survey.get("aerobic_weekly") or survey.get("resistance_weekly"):
        sections.append("activity")
    
    print(f"✅ [PlanSections] 섹션 계획 완료: {sections}")
    return {**state, "active_sections": sections}


# 노드 3: PreloadQuantEvidence (신규)
def preload_quant_evidence(state: ReportState) -> ReportState:
    """섹션별 정량 근거 먼저 확보 (grounded 또는 estimated)"""
    print("[PreloadQuantEvidence] 정량 근거 확보 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    
    quant_results = {}
    
    for section in sections:
        print(f"\n  [{section}] 정량 근거 검색 시작")
        section_quant = {
            "mode": "estimated",  # 기본값
            "selected_outcomes": [],
            "stats_by_outcome": {},
            "quant_refs": [],
        }
        
        if section == "goals":
            # goals: 사용자 outcomes 기반
            outcomes = survey.get("outcomes", [])
            for ui_outcome in outcomes:
                quant_outcome_list = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
                if not quant_outcome_list:
                    continue
                
                try:
                    stats = get_grouped_stats_multi(quant_outcome_list, exclude_suspicious=True)
                    if stats and stats.get("timeframe_groups"):
                        section_quant["mode"] = "grounded"
                        section_quant["selected_outcomes"].append(ui_outcome)
                        section_quant["stats_by_outcome"][ui_outcome] = stats
                        
                        # quant_refs 수집
                        for tf_days, group in stats["timeframe_groups"].items():
                            for card_dict in group.get("cards", []):
                                section_quant["quant_refs"].append({
                                    "point_id": f"{card_dict.get('chunk_id', '')}__{card_dict.get('row_uid', '')}",
                                    "paper_id": card_dict.get("paper_id", ""),
                                    "chunk_id": card_dict.get("chunk_id", ""),
                                    "outcome_mapped": card_dict.get("outcome_mapped", ""),
                                    "timeframe_days": tf_days,
                                    "effect_signed_value": card_dict.get("effect_signed_value"),
                                    "effect_unit": card_dict.get("effect_unit_filled", "%"),
                                    "p_value": card_dict.get("p_value_num"),
                                    "p_label": card_dict.get("p_label", ""),
                                    "source_snippet": card_dict.get("source_snippet", ""),
                                })
                        
                        print(f"    ✅ {ui_outcome} → grounded ({len(stats['timeframe_groups'])}개 timeframe)")
                except Exception as e:
                    print(f"    ⚠️ {ui_outcome} 검색 실패: {e}")
        else:
            # 일반 섹션: 후보 리스트 순회
            candidates = SECTION_OUTCOME_CANDIDATES.get(section, [])
            best_outcome = None
            best_stats = None
            best_count = 0
            
            for outcome in candidates:
                try:
                    stats = get_grouped_stats(outcome, exclude_suspicious=True)
                    if stats and stats.get("timeframe_groups"):
                        # 가장 많은 카드를 가진 timeframe 그룹 찾기
                        total_cards = sum(len(g.get("cards", [])) for g in stats["timeframe_groups"].values())
                        if total_cards > best_count:
                            best_count = total_cards
                            best_outcome = outcome
                            best_stats = stats
                except Exception as e:
                    continue
            
            if best_stats:
                section_quant["mode"] = "grounded"
                section_quant["selected_outcomes"] = [best_outcome]
                section_quant["stats_by_outcome"][best_outcome] = best_stats
                
                # quant_refs 수집
                for tf_days, group in best_stats["timeframe_groups"].items():
                    for card_dict in group.get("cards", []):
                        section_quant["quant_refs"].append({
                            "point_id": f"{card_dict.get('chunk_id', '')}__{card_dict.get('row_uid', '')}",
                            "paper_id": card_dict.get("paper_id", ""),
                            "chunk_id": card_dict.get("chunk_id", ""),
                            "outcome_mapped": card_dict.get("outcome_mapped", ""),
                            "timeframe_days": tf_days,
                            "effect_signed_value": card_dict.get("effect_signed_value"),
                            "effect_unit": card_dict.get("effect_unit_filled", "%"),
                            "p_value": card_dict.get("p_value_num"),
                            "p_label": card_dict.get("p_label", ""),
                            "source_snippet": card_dict.get("source_snippet", ""),
                        })
                
                print(f"    ✅ {best_outcome} → grounded ({len(best_stats['timeframe_groups'])}개 timeframe, {best_count}개 카드)")
            else:
                # estimated fallback
                estimated = calculate_estimated_stats(candidates)
                if estimated:
                    section_quant["mode"] = "estimated"
                    section_quant["selected_outcomes"] = candidates[:2]  # 상위 2개만
                    section_quant["stats_by_outcome"]["estimated"] = estimated
                    print(f"    ⚠️ grounded 없음 → estimated ({estimated['timeframe_label']}, {estimated['median']:.1f}%)")
                else:
                    print(f"    ❌ 정량 근거 없음 (grounded/estimated 모두 실패)")
        
        quant_results[section] = section_quant
    
    print(f"\n✅ [PreloadQuantEvidence] 완료 - {len(quant_results)}개 섹션")
    return {**state, "quant_evidence_results": quant_results}


# 노드 4: BuildQueries (quant 결과 반영)
def build_queries(state: ReportState) -> ReportState:
    """섹션별 검색 쿼리 생성 (quant 결과 반영)"""
    print("[BuildQueries] 검색 쿼리 생성 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    quant_results = state.get("quant_evidence_results", {})
    
    queries = {}
    
    for section in sections:
        section_quant = quant_results.get(section, {})
        selected_outcomes = section_quant.get("selected_outcomes", [])
        
        # 기본 쿼리
        base_queries = {
            "goals": f"피부 건강 {', '.join([OUTCOME_LABELS.get(o, o) for o in survey.get('outcomes', [])])} 개선",
            "sleep": "수면 패턴 피부 건강",
            "uv": "자외선 노출 피부 노화",
            "lifestyle": "음주 흡연 스트레스 피부",
            "activity": "운동 대사 피부 건강",
        }
        
        query = base_queries.get(section, f"{section} skin health")
        
        # quant 결과 반영
        if selected_outcomes:
            outcome_labels = [OUTCOME_LABELS.get(o, o) for o in selected_outcomes]
            query += f" {' '.join(outcome_labels)}"
            
            # timeframe 키워드 추가
            stats = section_quant.get("stats_by_outcome", {})
            if stats:
                for outcome_stats in stats.values():
                    if isinstance(outcome_stats, dict) and "timeframe_groups" in outcome_stats:
                        timeframes = list(outcome_stats["timeframe_groups"].keys())[:1]  # 첫 번째만
                        if timeframes:
                            tf_days = timeframes[0]
                            tf_label = timeframe_days_to_label(tf_days)
                            query += f" {tf_label}"
                            break
        
        queries[section] = query + " skin health improvement"
    
    print(f"✅ [BuildQueries] 쿼리 생성 완료")
    return {**state, "section_queries": queries}


# 노드 5: RetrieveNarrativeEvidence
def retrieve_narrative_evidence(state: ReportState) -> ReportState:
    """원문 근거 검색 (narrative only)"""
    print("[RetrieveNarrativeEvidence] 원문 근거 검색 시작")
    sections = state.get("active_sections", [])
    queries = state.get("section_queries", {})
    survey = state.get("survey", {})
    
    narrative_results = {}
    
    for section in sections:
        query = queries.get(section, "")
        if not query:
            narrative_results[section] = []
            continue
        
        # topics 설정
        topics = None
        if section == "goals":
            topics = survey.get("outcomes", [])
        elif section == "activity":
            topics = ["exercise"]
        
        try:
            search_input = QdrantSearchInput(
                query=query,
                top_k=5,
                topics=topics,
                section_norm=None,
                candidate_k=30,
                min_score=0.2
            )
            result = qdrant_search(search_input)
            narrative_results[section] = result.items
            print(f"  [{section}] 원문 근거 {len(result.items)}개 검색 완료")
        except Exception as e:
            print(f"  ⚠️ [{section}] 원문 검색 실패: {e}")
            narrative_results[section] = []
    
    print(f"✅ [RetrieveNarrativeEvidence] 완료")
    return {**state, "narrative_evidence": narrative_results}


# 노드 6: WriteSectionCards (4카드 JSON 생성)
def write_section_cards(state: ReportState) -> ReportState:
    """섹션별 4카드 JSON 생성"""
    print("[WriteSectionCards] 카드 생성 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    quant_results = state.get("quant_evidence_results", {})
    narrative_evidence = state.get("narrative_evidence", {})
    
    section_cards = {}
    
    for section in sections:
        print(f"\n  [{section}] 카드 생성 중...")
        
        section_quant = quant_results.get(section, {})
        narrative_items = narrative_evidence.get(section, [])
        
        # 프롬프트 구성
        prompt = _build_card_prompt(section, survey, section_quant, narrative_items)
        
        system_prompt = """당신은 피부과 전문의입니다. 사용자의 설문 데이터와 정량 근거를 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.
반드시 아래 JSON 구조를 따르세요:
{
  "cards": [
    {"type": "problem", "title": "현재 상태", "text": "2-3문장"},
    {"type": "cause", "title": "왜 이런 상태인가", "text": "2-3문장"},
    {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": [
      {"title": "Action 1", "detail": "설명"},
      {"title": "Action 2", "detail": "설명"},
      {"title": "Action 3", "detail": "설명"}
    ]},
    {"type": "simulation", "title": "12주 후 예상 경로", "text": "2-4문장", "meta": {
      "mode": "grounded" 또는 "estimated",
      "disclaimer_small": "estimated일 때만 필수"
    }}
  ]
}
한국어만 사용하고, 전문용어는 괄호로 풀이하세요. 숫자는 simulation 카드에서만 사용하세요."""
        
        try:
            cards_json = invoke_llm_json(prompt, system_prompt)
            if cards_json and "cards" in cards_json:
                section_cards[section] = cards_json["cards"]
                print(f"    ✅ {len(cards_json['cards'])}개 카드 생성 완료")
            else:
                print(f"    ⚠️ JSON 파싱 실패, 기본 카드 생성")
                section_cards[section] = _create_default_cards(section)
        except Exception as e:
            print(f"    ❌ 카드 생성 실패: {e}")
            section_cards[section] = _create_default_cards(section)
    
    print(f"\n✅ [WriteSectionCards] 완료")
    return {**state, "section_cards": section_cards}


def _build_card_prompt(section: str, survey: dict, section_quant: dict, narrative_items: list) -> str:
    """카드 생성 프롬프트 구성"""
    # 설문 데이터 요약
    survey_text = _format_survey_data(section, survey)
    
    # 정량 근거 요약
    quant_text = _format_quant_data(section_quant)
    
    # 원문 근거 요약
    narrative_text = "\n\n".join([item.text[:200] for item in narrative_items[:3]]) if narrative_items else "관련 근거 없음"
    
    return f"""섹션: {section}

[사용자 설문 데이터]
{survey_text}

[정량 근거]
{quant_text}

[원문 근거 (참고용)]
{narrative_text}

위 정보를 바탕으로 4개의 카드를 JSON 형식으로 생성하세요."""


def _format_survey_data(section: str, survey: dict) -> str:
    """섹션별 설문 데이터 포맷팅"""
    if section == "goals":
        outcomes = survey.get("outcomes", [])
        return f"피부 고민: {', '.join([OUTCOME_LABELS.get(o, o) for o in outcomes])}"
    elif section == "sleep":
        return f"평일 수면: {survey.get('sleep_hours_weekday', 'N/A')}시간, 수면의 질: {survey.get('sleep_quality_score', 'N/A')}/10점"
    elif section == "uv":
        return f"자외선 노출: {survey.get('uv_exposure_10to16', 'N/A')}, 선크림 빈도: {survey.get('sunscreen_frequency', 'N/A')}"
    elif section == "lifestyle":
        return f"흡연: {survey.get('smoking_status', 'N/A')}, 주당 음주: {survey.get('drinking_days_per_week', 'N/A')}일, 스트레스: {survey.get('stress_score', 'N/A')}/10점"
    elif section == "activity":
        return f"유산소: {survey.get('aerobic_weekly', 'N/A')}회/주, 근력: {survey.get('resistance_weekly', 'N/A')}회/주"
    return ""


def _format_quant_data(section_quant: dict) -> str:
    """정량 근거 데이터 포맷팅"""
    mode = section_quant.get("mode", "estimated")
    stats_by_outcome = section_quant.get("stats_by_outcome", {})
    
    if mode == "grounded" and stats_by_outcome:
        lines = []
        for outcome, stats in stats_by_outcome.items():
            if isinstance(stats, dict) and "timeframe_groups" in stats:
                for tf_days, group in stats["timeframe_groups"].items():
                    tf_label = timeframe_days_to_label(tf_days)
                    lines.append(f"{OUTCOME_LABELS.get(outcome, outcome)}: {tf_label} 후 평균 {group['mean']:.1f}% 변화 (범위: {group['min']:.1f}~{group['max']:.1f}%)")
        return "\n".join(lines) if lines else "정량 근거 없음"
    elif mode == "estimated" and "estimated" in stats_by_outcome:
        est = stats_by_outcome["estimated"]
        return f"추정치: {est['timeframe_label']} 후 약 {est['min']:.0f}~{est['max']:.0f}% 수준 (AI 추정)"
    return "정량 근거 없음"


def _create_default_cards(section: str) -> List[Dict[str, Any]]:
    """기본 카드 생성 (fallback)"""
    return [
        {"type": "problem", "title": "현재 상태", "text": "분석 중입니다."},
        {"type": "cause", "title": "왜 이런 상태인가", "text": "분석 중입니다."},
        {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": [
            {"title": "행동 1", "detail": "분석 중입니다."},
            {"title": "행동 2", "detail": "분석 중입니다."},
            {"title": "행동 3", "detail": "분석 중입니다."}
        ]},
        {"type": "simulation", "title": "12주 후 예상 경로", "text": "분석 중입니다.", "meta": {
            "mode": "estimated",
            "disclaimer_small": "정량 근거가 부족해 AI가 추정한 값입니다."
        }}
    ]


# 노드 7: AssembleReport
def assemble_report(state: ReportState) -> ReportState:
    """최종 리포트 조립 (카드 기반)"""
    print("[AssembleReport] 리포트 조립 시작")
    survey = state.get("survey", {})
    sections = state.get("active_sections", [])
    section_cards = state.get("section_cards", {})
    quant_results = state.get("quant_evidence_results", {})
    narrative_evidence = state.get("narrative_evidence", {})
    
    section_titles = {
        "goals": "주요 목표 분석 및 개선 방안",
        "sleep": "수면 및 리듬",
        "uv": "자외선 및 노화 관리",
        "lifestyle": "생활습관 관리",
        "activity": "활동 및 대사",
    }
    
    # 섹션별 리포트 구조 생성
    sections_dict = {}
    for section in sections:
        cards = section_cards.get(section, [])
        if not cards:
            continue
        
        # narrative refs 수집
        narrative_refs = []
        for item in narrative_evidence.get(section, []):
            narrative_refs.append({
                "paper_id": item.paper_id,
                "chunk_id": item.chunk_id,
                "title": item.title,
                "pmid": item.pmid,
                "section_norm": item.section_norm,
                "topics": item.topics,
            })
        
        # quant refs는 이미 quant_results에 있음
        quant_refs = quant_results.get(section, {}).get("quant_refs", [])
        
        sections_dict[section] = {
            "title": section_titles.get(section, section),
            "cards": cards,
            "evidence_refs": {
                "narrative": narrative_refs,
                "quant": quant_refs,
            }
        }
    
    final_report = {
        "tabs": sections,
        "sections": sections_dict,
        "survey_summary": {
            "outcomes": survey.get("outcomes", []),
            "target_years": survey.get("target_years", 30),
        },
        "generated_at": None,
    }
    
    print(f"✅ [AssembleReport] 완료 - {len(sections_dict)}개 섹션")
    return {**state, "final_report": final_report}


# 노드 8: SaveReport
def save_report_node(state: ReportState) -> ReportState:
    """리포트 저장"""
    print("[SaveReport] 리포트 저장 시작")
    user_id = state["user_id"]
    final_report = state.get("final_report")
    survey = state.get("survey", {})
    
    if not final_report:
        print("⚠️ [SaveReport] 저장할 리포트가 없습니다.")
        return state
    
    try:
        lifestyle_id = survey.get("lifestyle_id")
        result = save_report(user_id, final_report, lifestyle_id=lifestyle_id)
        
        if "error" in result:
            print(f"⚠️ [SaveReport] 저장 실패: {result['error']}")
        else:
            print(f"✅ [SaveReport] 저장 완료 - report_id: {result.get('report_id')}")
            final_report["report_id"] = result.get("report_id")
            final_report["generated_at"] = result.get("timestamp")
        
        return {**state, "final_report": final_report}
    except Exception as e:
        print(f"❌ [SaveReport] 저장 실패: {e}")
        return state


# LangGraph 워크플로우 구성
def create_report_graph():
    """리포트 생성 LangGraph 워크플로우 생성"""
    workflow = StateGraph(ReportState)
    
    workflow.add_node("load_survey", load_survey)
    workflow.add_node("plan_sections", plan_sections)
    workflow.add_node("preload_quant_evidence", preload_quant_evidence)
    workflow.add_node("build_queries", build_queries)
    workflow.add_node("retrieve_narrative_evidence", retrieve_narrative_evidence)
    workflow.add_node("write_section_cards", write_section_cards)
    workflow.add_node("assemble_report", assemble_report)
    workflow.add_node("save_report", save_report_node)
    
    workflow.set_entry_point("load_survey")
    workflow.add_edge("load_survey", "plan_sections")
    workflow.add_edge("plan_sections", "preload_quant_evidence")
    workflow.add_edge("preload_quant_evidence", "build_queries")
    workflow.add_edge("build_queries", "retrieve_narrative_evidence")
    workflow.add_edge("retrieve_narrative_evidence", "write_section_cards")
    workflow.add_edge("write_section_cards", "assemble_report")
    workflow.add_edge("assemble_report", "save_report")
    workflow.add_edge("save_report", END)
    
    memory = MemorySaver()
    app = workflow.compile(checkpointer=memory)
    
    return app


# 리포트 생성 함수
def generate_report(user_id: int, lifestyle_id: Optional[int] = None) -> Dict[str, Any]:
    """리포트 생성 메인 함수"""
    try:
        initial_state: ReportState = {
            "user_id": user_id,
            "lifestyle_id": lifestyle_id,
            "survey": None,
            "active_sections": [],
            "quant_evidence_results": {},
            "section_queries": {},
            "narrative_evidence": {},
            "section_cards": {},
            "final_report": None,
        }
        
        app = create_report_graph()
        config = {"configurable": {"thread_id": f"user_{user_id}"}}
        
        final_state = None
        for state in app.stream(initial_state, config):
            final_state = state
        
        if final_state:
            last_node_key = list(final_state.keys())[-1] if final_state else None
            if last_node_key:
                result_state = final_state[last_node_key]
            else:
                result_state = initial_state
            
            final_report = result_state.get("final_report")
            if final_report:
                return {"success": True, "report": final_report}
            else:
                return {"success": False, "error": "리포트 생성 실패"}
        else:
            return {"success": False, "error": "리포트 생성 실패"}
            
    except Exception as e:
        print(f"[오류] 리포트 생성 실패: {str(e)}")
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}
