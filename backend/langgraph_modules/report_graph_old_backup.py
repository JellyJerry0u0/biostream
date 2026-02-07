"""
LangGraph 기반 리포트 생성 워크플로우
Qdrant 중심 RAG + LangGraph 기반 리포트 오케스트레이션

노드 흐름:
1. LoadSurvey (tool)
2. PlanSections (rule-based)
3. BuildQueries (template-based, ko+en 혼합)
4. RetrieveEvidence (tool: qdrant_search) - 섹션별 병렬 가능 구조
5. WriteSectionDraft (LLM)
6. AssembleReport (LLM)
7. SaveReport (tool)
"""

import os
import json
import sys
import re
from typing import Dict, Any, List, Optional, TypedDict, Annotated
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage, SystemMessage
import google.generativeai as genai

# 패키지 langgraph import (로컬 디렉토리 이름 변경으로 충돌 해결)
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

# Tools import를 위해 경로 복원
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
    search_by_outcome, search_by_outcomes, get_grouped_stats, get_grouped_stats_multi,
    format_quant_summary, format_quant_block, QuantEvidenceCard
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


def clean_markdown(text: str) -> str:
    """마크다운 문법을 제거하여 깔끔한 텍스트로 변환"""
    if not text:
        return text
    
    # 볼드: **텍스트** 또는 __텍스트__ -> 텍스트
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
    text = re.sub(r'__(.+?)__', r'\1', text)
    
    # 이탤릭: *텍스트* 또는 _텍스트_ -> 텍스트 (볼드와 구분)
    text = re.sub(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)', r'\1', text)
    text = re.sub(r'(?<!_)_(?!_)(.+?)(?<!_)_(?!_)', r'\1', text)
    
    # 헤더: # 제목 -> 제목
    text = re.sub(r'^#{1,6}\s+(.+)$', r'\1', text, flags=re.MULTILINE)
    
    # 링크: [텍스트](url) -> 텍스트
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    
    # 이미지: ![alt](url) -> alt
    text = re.sub(r'!\[([^\]]*)\]\([^\)]+\)', r'\1', text)
    
    # 코드 블록: ```언어\n코드\n``` -> 코드
    text = re.sub(r'```[\w]*\n(.*?)\n```', r'\1', text, flags=re.DOTALL)
    
    # 인라인 코드: `코드` -> 코드
    text = re.sub(r'`([^`]+)`', r'\1', text)
    
    # 리스트 마커: - 항목 또는 * 항목 -> 항목
    text = re.sub(r'^[\s]*[-*+]\s+(.+)$', r'\1', text, flags=re.MULTILINE)
    text = re.sub(r'^[\s]*\d+\.\s+(.+)$', r'\1', text, flags=re.MULTILINE)
    
    # 수평선: --- 또는 *** -> 제거
    text = re.sub(r'^[-*]{3,}$', '', text, flags=re.MULTILINE)
    
    # 인용: > 텍스트 -> 텍스트
    text = re.sub(r'^>\s+(.+)$', r'\1', text, flags=re.MULTILINE)
    
    # 불필요한 공백 정리 (연속된 공백을 하나로)
    text = re.sub(r' +', ' ', text)
    
    # 연속된 줄바꿈을 최대 2개로 제한
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    # 앞뒤 공백 제거
    text = text.strip()
    
    return text


def invoke_llm_simple(prompt: str, system_prompt: str = "") -> str:
    """간단한 LLM 호출 (google.generativeai 직접 사용)"""
    if not GOOGLE_API_KEY:
        return "LLM이 초기화되지 않았습니다."
    
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
            # Fallback: google.generativeai 직접 사용
            if not genai_model_name:
                genai_model_name = "gemini-2.5-flash"
            model = genai.GenerativeModel(genai_model_name)
            full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
            response = model.generate_content(full_prompt)
            raw_text = response.text
        
        # 마크다운 문법 제거하여 깔끔한 텍스트로 변환
        cleaned_text = clean_markdown(raw_text)
        return cleaned_text
    except Exception as e:
        print(f"⚠️ LLM 호출 실패: {e}")
        return f"LLM 호출 실패: {str(e)}"


# State 정의
class ReportState(TypedDict):
    """리포트 생성 상태"""
    user_id: int
    lifestyle_id: Optional[int]  # 지정된 lifestyle_id (있으면 해당 설문 사용)
    survey: Optional[Dict[str, Any]]
    active_sections: List[str]  # 생성할 섹션 목록
    section_queries: Dict[str, str]  # 섹션별 검색 쿼리
    retrieval_results: Dict[str, List[EvidenceItem]]  # 섹션별 검색 결과 (원문 컬렉션)
    quant_evidence_results: Dict[str, Dict[str, Any]]  # 섹션별 정량 근거 결과
    evidence_bundles: Dict[str, str]  # 섹션별 근거 요약
    section_drafts: Dict[str, str]  # 섹션별 초안
    final_report: Optional[Dict[str, Any]]
    citations: List[Dict[str, Any]]  # 인용 정보
    quality_flags: Dict[str, bool]  # 품질 플래그


# 목표 한글 매핑 (UI outcomes)
OUTCOME_LABELS = {
    "wrinkle": "주름",
    "elasticity": "탄력",
    "pigmentation": "색소",
    "hydration": "수분",
    "hydration_barrier": "장벽",
    "acne": "여드름",
    "redness": "홍조",
    "general_aging": "전체 노화",
}

# outcome polarity 테이블 (개선 방향성)
OUTCOME_POLARITY = {
    "wrinkle": "decrease_is_improvement",
    "elasticity": "increase_is_improvement",
    "pigmentation": "decrease_is_improvement",
    "hydration": "increase_is_improvement",
    "hydration_barrier": "increase_is_improvement",
    "acne": "decrease_is_improvement",
    "redness": "decrease_is_improvement",
    "general_aging": "mixed",
    # quant_evidence의 outcome_mapped도 포함
    "general_skin": "mixed",
}

# UI outcomes → quant_evidence.outcome_mapped 매핑 (1:N 확장)
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

# 기존 호환성을 위한 단일 매핑 (deprecated, 확장 매핑 사용 권장)
OUTCOME_TO_MAPPED = {
    "wrinkle": "wrinkle",
    "elasticity": "elasticity",
    "pigmentation": "pigmentation",
    "hydration": "hydration_barrier",
    "hydration_barrier": "hydration_barrier",
    "acne": "acne",
    "redness": "redness",
    "general_aging": None,
}

# 섹션별 outcome_mapped 매핑 (일반 섹션용)
# goals 섹션은 사용자 목표 키워드를 사용하므로 여기에 포함하지 않음
SECTION_TO_OUTCOME_MAPPED = {
    "sleep": None,  # sleep 섹션은 정량 근거 없음 (또는 다른 outcome 사용)
    "uv": None,  # uv 섹션은 정량 근거 없음
    "lifestyle": None,  # lifestyle 섹션은 정량 근거 없음
    "activity": None,  # activity 섹션은 정량 근거 없음
    # 필요시 추가:
    # "elasticity": "elasticity",
    # "pigmentation": "pigmentation",
    # "hydration_barrier": "hydration_barrier",
}


# 노드 1: LoadSurvey (tool)
def load_survey(state: ReportState) -> ReportState:
    """설문 데이터 로드"""
    user_id = state["user_id"]
    lifestyle_id = state.get("lifestyle_id")
    
    if lifestyle_id:
        print(f"[LoadSurvey] lifestyle_id={lifestyle_id} 설문 데이터 로드 시작")
    else:
        print(f"[LoadSurvey] user_id={user_id} 최신 설문 데이터 로드 시작")
    
    try:
        # lifestyle_id가 지정되면 해당 설문 사용, 없으면 최신 설문 사용
        survey = get_survey(user_id, lifestyle_id=lifestyle_id)
        if "error" in survey:
            print(f"⚠️ [LoadSurvey] 오류: {survey['error']}")
            return {**state, "survey": None}
        print(f"✅ [LoadSurvey] 설문 데이터 로드 완료 - lifestyle_id={survey.get('lifestyle_id')}")
        return {**state, "survey": survey}
    except Exception as e:
        print(f"❌ [LoadSurvey] 실패: {e}")
        return {**state, "survey": None}


# 노드 2: PlanSections (rule-based)
def plan_sections(state: ReportState) -> ReportState:
    """생성할 섹션 계획 (rule-based)"""
    print("[PlanSections] 섹션 계획 시작")
    survey = state.get("survey")
    if not survey:
        return {**state, "active_sections": []}
    
    # 기본 섹션 목록
    sections = ["goals"]  # 주요 목표는 항상 포함
    
    # 설문 데이터 기반으로 섹션 추가
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


# 노드 3: BuildQueries (template-based, ko+en 혼합)
def build_queries(state: ReportState) -> ReportState:
    """섹션별 검색 쿼리 생성 (template-based)"""
    print("[BuildQueries] 검색 쿼리 생성 시작")
    survey = state.get("survey", {})
    sections = state.get("active_sections", [])
    
    queries = {}
    
    # 섹션별 쿼리 템플릿
    query_templates = {
        "goals": lambda s: f"피부 건강 {', '.join([OUTCOME_LABELS.get(o, o) for o in s.get('outcomes', [])])} 개선 방법 skin health improvement",
        "sleep": lambda s: f"수면 패턴 피부 건강 영향 sleep pattern skin health impact",
        "uv": lambda s: f"자외선 노출 피부 노화 UV exposure photoaging prevention",
        "lifestyle": lambda s: f"음주 흡연 스트레스 피부 건강 alcohol smoking stress skin health",
        "activity": lambda s: f"운동 대사 피부 건강 exercise metabolism skin health",
    }
    
    for section in sections:
        if section in query_templates:
            queries[section] = query_templates[section](survey)
        else:
            queries[section] = f"{section} skin health"
    
    print(f"✅ [BuildQueries] 쿼리 생성 완료: {list(queries.keys())}")
    return {**state, "section_queries": queries}


# 노드 4: RetrieveEvidence (tool: qdrant_search) - 섹션별 검색 (2-컬렉션)
def retrieve_evidence(state: ReportState) -> ReportState:
    """섹션별 근거 검색 (원문 + 정량 근거)"""
    print("[RetrieveEvidence] 근거 검색 시작 (2-컬렉션)")
    queries = state.get("section_queries", {})
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    
    retrieval_results = {}  # 원문 컬렉션 결과
    quant_evidence_results = {}  # 정량 근거 결과
    all_citations = []
    
    # 사용자의 outcomes
    outcomes = survey.get("outcomes", [])
    
    # 섹션별 검색 수행
    for section in sections:
        if section not in queries:
            continue
        
        query = queries[section]
        
        # 1. 원문 컬렉션 검색 (biostream_corpus_v1)
        section_mapping = {
            "goals": {"topics": outcomes},  # outcomes를 topics로 사용
            "sleep": {"topics": None},
            "uv": {"topics": None},
            "lifestyle": {"topics": None},
            "activity": {"topics": ["exercise"]},
        }
        
        mapping = section_mapping.get(section, {"topics": None})
        
        try:
            search_input = QdrantSearchInput(
                query=query,
                top_k=5,
                topics=mapping.get("topics"),
                section_norm=None,
                candidate_k=30,
                min_score=0.2
            )
            
            result = qdrant_search(search_input)
            retrieval_results[section] = result.items
            
            # 인용 정보 수집
            for item in result.items:
                all_citations.append({
                    "paper_id": item.paper_id,
                    "chunk_id": item.chunk_id,
                    "section_norm": item.section_norm,
                    "topics": item.topics,
                    "pmid": item.pmid,
                    "title": item.title
                })
            
            print(f"  [{section}] 원문 근거 {len(result.items)}개 검색 완료")
        except Exception as e:
            print(f"  ⚠️ [{section}] 원문 검색 실패: {e}")
            retrieval_results[section] = []
        
        # 2. 정량 근거 검색 (quant_evidence) - 모든 섹션에서 수행 (확장 매핑 사용)
        quant_results = {}
        
        if section == "goals":
            # goals 섹션: 사용자 목표 키워드를 확장 매핑으로 변환
            print(f"  [{section}] 정량 근거 검색 시작 (사용자 outcomes: {outcomes})")
            if outcomes:
                for ui_outcome in outcomes:
                    # UI outcome → quant_outcome 리스트로 확장 매핑
                    quant_outcome_list = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
                    if not quant_outcome_list:
                        print(f"  [{section}] 정량 근거 없음 ({ui_outcome} → 매핑 없음)")
                        print(f"     사용 가능한 매핑: {list(UI_OUTCOME_TO_QUANT_MAPPED.keys())}")
                        continue
                    
                    print(f"  [{section}] {ui_outcome} → {quant_outcome_list} 매핑으로 검색 시작")
                    try:
                        # 확장 매핑된 outcome 리스트로 통계 계산
                        stats = get_grouped_stats_multi(quant_outcome_list, exclude_suspicious=True)
                        if stats and stats.get("timeframe_groups"):
                            quant_results[ui_outcome] = stats
                            print(f"  ✅ [{section}] 정량 근거 발견 ({ui_outcome} → {quant_outcome_list}): {len(stats.get('timeframe_groups', {}))}개 timeframe 그룹")
                        else:
                            print(f"  ⚠️ [{section}] 정량 근거 없음 ({ui_outcome} → {quant_outcome_list}): timeframe_groups가 비어있음")
                            if stats:
                                print(f"     stats 내용: {list(stats.keys())}")
                    except Exception as e:
                        print(f"  ❌ [{section}] 정량 근거 검색 실패 ({ui_outcome} → {quant_outcome_list}): {e}")
                        import traceback
                        traceback.print_exc()
                        quant_results[ui_outcome] = None
            else:
                print(f"  [{section}] 사용자 outcomes가 없음")
        else:
            # 일반 섹션: 섹션별 outcome_mapped 사용 (확장 매핑 미사용)
            outcome_mapped = SECTION_TO_OUTCOME_MAPPED.get(section)
            if outcome_mapped:
                try:
                    # 정량 근거 통계 계산
                    stats = get_grouped_stats(outcome_mapped, exclude_suspicious=True)
                    if stats and stats.get("timeframe_groups"):
                        quant_results[outcome_mapped] = stats
                        print(f"  [{section}] 정량 근거 ({outcome_mapped}): {len(stats.get('timeframe_groups', {}))}개 timeframe 그룹")
                except Exception as e:
                    print(f"  ⚠️ [{section}] 정량 근거 검색 실패 ({outcome_mapped}): {e}")
                    quant_results[outcome_mapped] = None
            else:
                # outcome_mapped가 None인 섹션은 정량 근거 없음
                print(f"  [{section}] 정량 근거 없음 (outcome_mapped 매핑 없음)")
        
        if quant_results:
            quant_evidence_results[section] = quant_results
    
    # 중복 제거된 인용 정보
    unique_citations = []
    seen = set()
    for cit in all_citations:
        key = (cit["paper_id"], cit["chunk_id"])
        if key not in seen:
            seen.add(key)
            unique_citations.append(cit)
    
    print(f"✅ [RetrieveEvidence] 검색 완료 - 원문: {len(unique_citations)}개, 정량: {len(quant_evidence_results)}개 섹션")
    return {
        **state,
        "retrieval_results": retrieval_results,
        "quant_evidence_results": quant_evidence_results,
        "citations": unique_citations
    }


# 노드 5: WriteSectionDraft (LLM)
def write_section_draft(state: ReportState) -> ReportState:
    """섹션별 초안 작성 (LLM) - 2-컬렉션 통합"""
    print("[WriteSectionDraft] 섹션 초안 작성 시작 (2-컬렉션)")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    retrieval_results = state.get("retrieval_results", {})
    quant_evidence_results = state.get("quant_evidence_results", {})
    
    section_drafts = {}
    
    for section in sections:
        evidence_items = retrieval_results.get(section, [])
        
        # 근거 텍스트 수집 (원문 컬렉션)
        evidence_texts = []
        for item in evidence_items:
            evidence_texts.append(f"[{item.paper_id}] {item.text}")
        
        evidence_summary = "\n\n".join(evidence_texts) if evidence_texts else "관련 근거가 없습니다."
        
        # 정량 근거 수집 (quant_evidence 컬렉션) - 모든 섹션에서 수행
        quant_summary_text = ""
        quant_results = {}
        
        if section in quant_evidence_results:
            quant_results = quant_evidence_results[section]
            
            # 정량 근거를 한국어 요약으로 변환 (카드/PMC ID 제거)
            from quant_evidence_retriever import format_quant_summary
            
            if section == "goals":
                # goals 섹션: 사용자 목표 키워드별로 정량 요약 생성
                outcomes = survey.get('outcomes', [])
                summary_list = []
                
                for ui_outcome in outcomes:
                    if ui_outcome not in quant_results:
                        continue
                    
                    stats = quant_results[ui_outcome]
                    if not stats:
                        continue
                    
                    summary = format_quant_summary(stats, outcome_mapped=ui_outcome, outcome_polarity_map=OUTCOME_POLARITY)
                    if summary and summary != "정량 근거 없음":
                        summary_list.append(f"{OUTCOME_LABELS.get(ui_outcome, ui_outcome)}: {summary}")
                
                quant_summary_text = "\n".join(summary_list) if summary_list else "정량 근거 없음"
            else:
                # 일반 섹션: outcome_mapped별로 정량 요약 생성
                summary_list = []
                
                for outcome_mapped, stats in quant_results.items():
                    if not stats:
                        continue
                    
                    summary = format_quant_summary(stats, outcome_mapped=outcome_mapped, outcome_polarity_map=OUTCOME_POLARITY)
                    if summary and summary != "정량 근거 없음":
                        summary_list.append(summary)
                
                quant_summary_text = "\n".join(summary_list) if summary_list else "정량 근거 없음"
        else:
            quant_summary_text = "정량 근거 없음"
        
        # 사용자의 주요 피부 고민
        outcomes_text = ', '.join([OUTCOME_LABELS.get(o, o) for o in survey.get('outcomes', [])])
        
        # 코치형 프롬프트 생성
        import sys
        import os
        sys.path.append(os.path.join(os.path.dirname(__file__)))
        from report_prompts_coach import build_coach_prompt
        prompt = build_coach_prompt(
            section=section,
            survey=survey,
            evidence_summary=evidence_summary,
            quant_summary_text=quant_summary_text,
            outcomes_text=outcomes_text
        )
        
        try:
            system_prompt = "당신은 피부과 전문의입니다. 사용자의 설문 데이터를 보고 조용히 설명해주는 톤으로 작성하세요. 과장하지 말고, 공포 마케팅을 하지 말고, 사용자를 비난하지 말되, 회피하지 말고 단정적으로 말하세요."
            draft = invoke_llm_simple(prompt, system_prompt)
            section_drafts[section] = draft
            print(f"  [{section}] 초안 작성 완료")
        except Exception as e:
            print(f"  ⚠️ [{section}] 초안 작성 실패: {e}")
            section_drafts[section] = f"[{section}] 섹션 생성 중 오류가 발생했습니다."
    
    print(f"✅ [WriteSectionDraft] 초안 작성 완료")
    return {**state, "section_drafts": section_drafts}


# 노드 6: AssembleReport (LLM)
def assemble_report(state: ReportState) -> ReportState:
    """최종 리포트 조립 (코치형 헬스 리포트)"""
    print("[AssembleReport] 최종 리포트 조립 시작")
    survey = state.get("survey", {})
    section_drafts = state.get("section_drafts", {})
    citations = state.get("citations", [])
    quant_evidence_results = state.get("quant_evidence_results", {})
    
    # 섹션별 제목 매핑
    section_titles = {
        "goals": "주요 목표 분석 및 개선 방안",
        "sleep": "수면 및 리듬",
        "uv": "자외선 및 노화 관리",
        "lifestyle": "생활습관 관리",
        "activity": "활동 및 대사",
    }
    
    # 섹션 내용 수집
    sections_text = []
    for section, draft in section_drafts.items():
        title = section_titles.get(section, section)
        sections_text.append(f"{title}\n\n{draft}")
    
    report_content = "\n\n".join(sections_text)
    
    # 헤더: 한 줄 결론 + 가장 ROI 큰 변화 2개
    outcomes = survey.get("outcomes", [])
    outcomes_labels = [OUTCOME_LABELS.get(o, o) for o in outcomes]
    outcomes_text = ', '.join(outcomes_labels)
    
    # 정량 근거가 가장 많은 섹션 2개 찾기
    top_sections = []
    for section_name, quant_results in quant_evidence_results.items():
        if quant_results:
            total_cards = sum(
                len(stats.get("timeframe_groups", {})) 
                for stats in quant_results.values() 
                if isinstance(stats, dict)
            )
            if total_cards > 0:
                top_sections.append((section_name, total_cards))
    
    top_sections.sort(key=lambda x: x[1], reverse=True)
    top_2_sections = [s[0] for s in top_sections[:2]] if top_sections else ["goals", "sleep"]
    
    header_prompt = f"""당신은 피부 코치입니다. 아래 리포트를 요약하여 헤더를 작성하세요.

[사용자 피부 고민]
{outcomes_text}

[리포트 내용]
{report_content[:2000]}

[작성 요구사항]
- 한 줄 결론: 사용자의 현재 상태를 한 문장으로 요약 (50자 내외)
- 가장 ROI 큰 변화 2개: {', '.join([section_titles.get(s, s) for s in top_2_sections])} 섹션에서 가장 중요한 변화 2가지를 각각 1문장으로 제시 (각 30자 내외)
- 한국어만 사용, 전문 용어 금지, 마크다운 없음

형식:
한 줄 결론: [한 문장]

이번 리포트에서 가장 ROI 큰 변화 2개:
1. [변화 1]
2. [변화 2]
"""
    
    # 엔딩: 이번 주 체크리스트
    ending_prompt = f"""당신은 피부 코치입니다. 아래 리포트를 바탕으로 이번 주 체크리스트를 작성하세요.

[리포트 내용]
{report_content[:2000]}

[작성 요구사항]
- 이번 주부터 바로 할 수 있는 행동 3가지를 제시하세요.
- 각 행동은 측정 가능해야 합니다 (예: 주 5회, 하루 1회, 2주간 유지 등).
- 정량 효과(%)는 쓰지 마세요.
- 한국어만 사용, 마크다운 없음

형식:
이번 주 체크리스트:
1. [행동 1]
2. [행동 2]
3. [행동 3]
"""
    
    try:
        header = invoke_llm_simple(header_prompt, "당신은 피부 코치입니다. 짧고 명확하게 요약하세요.")
        ending = invoke_llm_simple(ending_prompt, "당신은 피부 코치입니다. 실행 가능한 행동만 제시하세요.")
    except Exception as e:
        print(f"  ⚠️ [AssembleReport] 헤더/엔딩 생성 실패: {e}")
        header = f"한 줄 결론: 현재 {outcomes_text} 상태를 개선할 수 있는 기회가 있습니다."
        ending = "이번 주 체크리스트:\n1. 리포트의 행동 제안을 확인하세요\n2. 가장 쉬운 것부터 시작하세요\n3. 2주간 지속해보세요"
    
    # 최종 리포트 구조 생성
    final_report = {
        "header": header,
        "sections": section_drafts,
        "ending": ending,
        "citations": citations,
        "survey_summary": {
            "outcomes": survey.get("outcomes", []),
            "target_years": survey.get("target_years", 30),
        },
        "generated_at": None  # 나중에 저장 시점에 설정
    }
    
    # 최종 리포트 텍스트를 로그로 출력
    print("\n" + "="*80)
    print("📄 생성된 건강 리포트")
    print("="*80)
    print(f"\n{header}\n")
    for section, draft in section_drafts.items():
        title = section_titles.get(section, section)
        print(f"\n--- {title} ---")
        print(draft)
    print(f"\n{ending}\n")
    print("="*80 + "\n")
    
    print(f"✅ [AssembleReport] 리포트 조립 완료 - {len(section_drafts)}개 섹션")
    return {**state, "final_report": final_report}


# 노드 7: SaveReport (tool)
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
            # 리포트에 저장 정보 추가
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
    
    # 노드 추가
    workflow.add_node("load_survey", load_survey)
    workflow.add_node("plan_sections", plan_sections)
    workflow.add_node("build_queries", build_queries)
    workflow.add_node("retrieve_evidence", retrieve_evidence)
    workflow.add_node("write_section_draft", write_section_draft)
    workflow.add_node("assemble_report", assemble_report)
    workflow.add_node("save_report", save_report_node)
    
    # 엣지 설정
    workflow.set_entry_point("load_survey")
    workflow.add_edge("load_survey", "plan_sections")
    workflow.add_edge("plan_sections", "build_queries")
    workflow.add_edge("build_queries", "retrieve_evidence")
    workflow.add_edge("retrieve_evidence", "write_section_draft")
    workflow.add_edge("write_section_draft", "assemble_report")
    workflow.add_edge("assemble_report", "save_report")
    workflow.add_edge("save_report", END)
    
    # 메모리 체크포인터 추가
    memory = MemorySaver()
    app = workflow.compile(checkpointer=memory)
    
    return app


# 리포트 생성 함수 (외부에서 호출)
def generate_report(user_id: int, lifestyle_id: Optional[int] = None) -> Dict[str, Any]:
    """
    리포트 생성 메인 함수
    
    Args:
        user_id: 사용자 ID
        lifestyle_id: 특정 Lifestyle 레코드 ID (지정하면 해당 설문 사용, None이면 최신 설문)
    
    Returns:
        리포트 데이터
    """
    try:
        # 초기 상태 생성
        initial_state: ReportState = {
            "user_id": user_id,
            "lifestyle_id": lifestyle_id,
            "survey": None,
            "active_sections": [],
            "section_queries": {},
            "retrieval_results": {},
            "quant_evidence_results": {},
            "evidence_bundles": {},
            "section_drafts": {},
            "final_report": None,
            "citations": [],
            "quality_flags": {}
        }
        
        # 워크플로우 실행
        app = create_report_graph()
        config = {"configurable": {"thread_id": f"user_{user_id}"}}
        
        final_state = None
        for state in app.stream(initial_state, config):
            final_state = state
        
        if final_state:
            # 마지막 상태에서 결과 추출
            last_node_key = list(final_state.keys())[-1] if final_state else None
            if last_node_key:
                result_state = final_state[last_node_key]
            else:
                result_state = initial_state
            
            final_report = result_state.get("final_report")
            if final_report:
                return {
                    "success": True,
                    "report": final_report
                }
            else:
                return {
                    "success": False,
                    "error": "리포트 생성 실패"
                }
        else:
            return {
                "success": False,
                "error": "리포트 생성 실패"
            }
            
    except Exception as e:
        print(f"[오류] 리포트 생성 실패: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e)
        }
