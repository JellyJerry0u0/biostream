"""
리포트 생성 파이프라인 (LangGraph + Quant-First 아키텍처)
정량 근거를 먼저 확보하고, 그를 중심으로 서술을 생성하는 구조

노드 흐름 (LangGraph StateGraph):
1. LoadSurvey
2. PlanSections
2.5. DeriveUserProfile
3. PreloadQuantEvidence
4. BuildQueries
5. RetrieveNarrativeEvidence
5.5. ExtractClaims (rule-based)
6. WriteSectionCards
6.5. ValidateCards → (재시도 시 WriteSectionCards / 아니면 AssembleReport)
7. AssembleReport
8. GenerateAgingImage (DB의 /generate→skin-edit 결과만 연결, GPU 미호출)
9. SaveReport
10. ExportToNotion (Notion으로 리포트 전송)
"""

import os
import re
import json
import sys
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, Any, List, Optional, Tuple, TypedDict
from collections import defaultdict, OrderedDict

# Tools import
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(backend_dir)
from tools.survey_tool import get_survey
from tools.qdrant_search import qdrant_search
from tools.report_store import save_report
from tools.schemas import QdrantSearchInput, EvidenceItem
from tools.notion_integration import export_report_to_notion
#from tools.notion_integration_mcp import export_report_to_notion
from app.database import SessionLocal
from app import models
from datetime import date

# 정량 근거 검색 모듈 import
services_dir = os.path.join(backend_dir, "app", "services")
if services_dir not in sys.path:
    sys.path.append(services_dir)
from quant_evidence_retriever import (
    search_by_outcomes,
    QuantEvidenceCard
)
# ── 서브모듈 import ──
from .report_constants import (
    ReportState,
    OUTCOME_LABELS,
    UI_OUTCOME_TO_QUANT_MAPPED,
    OUTCOME_TO_NARRATIVE_TOPICS,
    SECTION_OUTCOME_CANDIDATES,
    SECTION_PRIMARY_OUTCOME,
    SECTION_CARD_TYPE_KEYWORDS,
    SECTION_TITLES,
    SECTION_SURVEY_EXTRACT,
    SECTION_INJECT_SUFFIX,
    LIFESTYLE_SECTIONS,
)
from .report_llm import get_llm_call_count
from .report_formatters import (
    map_outcomes_to_topics,
    timeframe_days_to_label,
    calculate_user_profile_derived,
    format_user_profile_for_prompt,
    normalize_survey_value,
    simulation_effect_phrase,
    strip_markdown,
    visual_simulation_chart_values,
)
from .report_quant import preload_quant_evidence
from .report_llm import REPORT_DEBUG
from .report_cards import (
    generate_section_cards,
    generate_lifestyle_cards,
    build_dual_queries,
    extract_keyword_based_sentences,
    validate_section_cards,
)

# ── 하위 호환 re-export ──
# 테스트 파일에서 from report_modules.report_graph import X 로 사용 중인 심볼:
#   ReportState, SECTION_CARD_TYPE_KEYWORDS, OUTCOME_TO_NARRATIVE_TOPICS,
#   map_outcomes_to_topics → 위 import에서 자동 re-export
_extract_keyword_based_sentences = extract_keyword_based_sentences  # noqa: F841


def _llm_cache_get(key: str) -> Optional[Dict[str, Any]]:
    """LRU 캐시에서 값 가져오기 (접근 시 최신으로 이동)"""
    if key in _llm_cache:
        # 접근한 항목을 맨 뒤로 이동 (LRU)
        value = _llm_cache.pop(key)
        _llm_cache[key] = value
        return value
    return None


def _llm_cache_set(key: str, value: Optional[Dict[str, Any]]) -> None:
    """LRU 캐시에 값 저장 (크기 제한 적용)"""
    # 이미 존재하면 제거 후 다시 추가 (최신으로 이동)
    if key in _llm_cache:
        _llm_cache.pop(key)
    
    # 새 항목 추가
    _llm_cache[key] = value
    
    # 크기 제한 초과 시 가장 오래된 항목 제거
    while len(_llm_cache) > _llm_cache_max_size:
        _llm_cache.popitem(last=False)  # 가장 오래된 항목 제거


# LLM 호출 카운터 (리포트 생성당)
_llm_call_count = 0


def extract_json_from_text(text: str, debug: bool = False) -> tuple[Optional[Dict[str, Any]], str]:
    """LLM 응답에서 JSON만 추출 (원인 분리 로그 포함)
    
    Returns:
        (parsed_json, failure_reason)
        - parsed_json: 파싱 성공 시 dict, 실패 시 None
        - failure_reason: 실패 시 원인 설명 ("" if success)
    """
    original_text = text
    attempt_patterns = []
    
    # 패턴 1: ```json 블록 찾기
    json_match = re.search(r'```json\s*\n(.*?)\n```', text, re.DOTALL)
    if json_match:
        text = json_match.group(1)
        attempt_patterns.append("```json 블록")
        try:
            result = json.loads(text.strip())
            if debug:
                print(f"    ✅ JSON 파싱 성공 (패턴: ```json 블록)")
            return result, ""
        except json.JSONDecodeError as e:
            if debug:
                print(f"    ⚠️ ```json 블록 추출했지만 파싱 실패: {str(e)[:100]}")
    
    # 패턴 2: ``` 블록 찾기
    json_match = re.search(r'```\s*\n(.*?)\n```', original_text, re.DOTALL)
    if json_match:
        text = json_match.group(1)
        attempt_patterns.append("``` 블록")
        try:
            result = json.loads(text.strip())
            if debug:
                print(f"    ✅ JSON 파싱 성공 (패턴: ``` 블록)")
            return result, ""
        except json.JSONDecodeError as e:
            if debug:
                print(f"    ⚠️ ``` 블록 추출했지만 파싱 실패: {str(e)[:100]}")
    
    # 패턴 3: { } 블록 찾기
    json_match = re.search(r'\{.*\}', original_text, re.DOTALL)
    if json_match:
        text = json_match.group(0)
        attempt_patterns.append("{ } 블록")
        try:
            result = json.loads(text.strip())
            if debug:
                print(f"    ✅ JSON 파싱 성공 (패턴: {{ }} 블록)")
            return result, ""
        except json.JSONDecodeError as e:
            if debug:
                print(f"    ⚠️ {{ }} 블록 추출했지만 파싱 실패: {str(e)[:100]}")
    
    # 패턴 4: 앞뒤 불필요한 텍스트 제거 후 재시도
    cleaned = re.sub(r'^[^{]*', '', original_text)
    cleaned = re.sub(r'[^}]*$', '', cleaned)
    if cleaned != original_text:
        attempt_patterns.append("앞뒤 텍스트 제거")
        try:
            result = json.loads(cleaned.strip())
            if debug:
                print(f"    ✅ JSON 파싱 성공 (패턴: 앞뒤 텍스트 제거)")
            return result, ""
        except json.JSONDecodeError as e:
            if debug:
                print(f"    ⚠️ 앞뒤 텍스트 제거했지만 파싱 실패: {str(e)[:100]}")
    
    # 모든 패턴 실패
    failure_reason = f"모든 패턴 실패 (시도: {', '.join(attempt_patterns) if attempt_patterns else '없음'})"
    if debug:
        print(f"    ❌ JSON 파싱 실패: {failure_reason}")
        print(f"    📝 원문 앞 500자: {original_text[:500]}")
    return None, failure_reason


def invoke_llm_json(prompt: str, system_prompt: str = "", retry: bool = True, context: str = "") -> Optional[Dict[str, Any]]:
    """LLM 호출하여 JSON 응답 파싱 (repair 재시도 + 관측 가능성 강화 + 429 처리 + 캐싱)
    
    Args:
        prompt: 사용자 프롬프트
        system_prompt: 시스템 프롬프트
        retry: 재시도 여부
        context: 디버그용 컨텍스트 (예: "extract_claims.sleep.problem")
    
    Returns:
        파싱된 JSON dict 또는 None
    """
    global _llm_call_count
    
    if not GOOGLE_API_KEY:
        print(f"  ❌ [{context}] LLM 호출 실패: GEMINI_API_KEY 없음")
        return None
    
    debug = REPORT_DEBUG
    
    # failure_reason 초기화
    failure_reason = ""
    
    # 캐싱: 동일한 프롬프트는 캐시에서 반환
    cache_key = hashlib.md5((system_prompt + prompt).encode()).hexdigest()
    cached_result = _llm_cache_get(cache_key)
    if cached_result is not None:
        if debug:
            print(f"  💾 [{context}] 캐시 히트 (호출 스킵)")
        return cached_result
    
    _llm_call_count += 1
    if debug:
        print(f"  📊 [LLMBudget] 호출 횟수: {_llm_call_count}회")
    
    # 429 에러 처리: 모델 폴백 리스트
    current_models = [genai_model_name] if genai_model_name else []
    current_models.extend([m for m in fallback_models if m != genai_model_name])
    
    last_error = None
    last_raw_text = ""
    last_failure_reason = ""
    
    # 모델 폴백 루프: 파싱 실패 시에도 다음 모델 시도 가능
    for attempt_idx, model_name in enumerate(current_models):
        try:
            # 429 에러 시 백오프 (첫 시도 제외)
            if attempt_idx > 0:
                backoff_seconds = min(2 ** attempt_idx, 8)  # 2s, 4s, 8s
                print(f"  ⏳ [{context}] 모델 폴백 대기: {backoff_seconds}초...")
                time.sleep(backoff_seconds)
            
            raw_text = ""
            if llm and model_name == genai_model_name:
                messages = []
                if system_prompt:
                    messages.append(SystemMessage(content=system_prompt))
                messages.append(HumanMessage(content=prompt))
                response = llm.invoke(messages)
                raw_text = response.content if hasattr(response, 'content') else str(response)
            else:
                model = genai.GenerativeModel(model_name)
                full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
                response = model.generate_content(full_prompt)
                raw_text = response.text
            
            if debug:
                print(f"  📝 [{context}] LLM 호출 성공 (모델: {model_name}), raw_text 길이: {len(raw_text)}")
                print(f"  📝 [{context}] raw_text 앞 500자: {raw_text[:500]}")
            
            result, parse_failure_reason = extract_json_from_text(raw_text, debug=debug)
            failure_reason = parse_failure_reason
            
            if result is not None:
                # 캐시에 저장
                _llm_cache_set(cache_key, result)
                if debug:
                    print(f"  ✅ [{context}] JSON 파싱 성공 (모델: {model_name})")
                return result
            
            # 파싱 실패: raw_text와 failure_reason 저장 후 다음 모델로 폴백 가능
            last_raw_text = raw_text
            last_failure_reason = parse_failure_reason
            if debug:
                print(f"  ⚠️ [{context}] JSON 파싱 실패 (모델: {model_name}): {parse_failure_reason}")
            
            # 파싱 실패해도 다음 모델로 폴백 시도 (마지막 모델이 아니면)
            if attempt_idx < len(current_models) - 1:
                continue
            
        except Exception as e:
            error_str = str(e)
            last_error = e
            
            # 429 에러 감지
            is_429 = (
                "429" in error_str or 
                "RESOURCE_EXHAUSTED" in error_str.upper() or
                "quota" in error_str.lower() or
                "rate limit" in error_str.lower()
            )
            
            if is_429:
                print(f"  ⚠️ [{context}] 429 에러 발생 (모델: {model_name}): {error_str[:200]}")
                # 다음 모델로 폴백 계속
                if attempt_idx < len(current_models) - 1:
                    continue
                else:
                    print(f"  ❌ [{context}] 모든 모델에서 429 에러, 규칙 기반 fallback으로 전환")
                    _llm_cache_set(cache_key, None)
                    return None
            else:
                # 429가 아닌 다른 에러는 다음 모델로 폴백 시도
                print(f"  ⚠️ [{context}] LLM 호출 실패 (모델: {model_name}): {error_str[:200]}")
                if attempt_idx < len(current_models) - 1:
                    continue
                else:
                    # 마지막 모델에서도 실패하면 재시도 로직으로
                    break
    
    # 모든 모델에서 파싱 실패 시 재시도 로직 (raw_text가 있고 429가 아닐 때만)
    if retry and last_raw_text and not (last_error and ("429" in str(last_error) or "RESOURCE_EXHAUSTED" in str(last_error).upper())):
        # 2차 시도: temperature 낮춤
        if debug:
            print(f"  🔄 [{context}] JSON 파싱 실패, 2차 시도 (temperature=0.2)...")
        try:
            model = genai.GenerativeModel(genai_model_name or current_models[0])
            generation_config = genai.types.GenerationConfig(temperature=0.2)
            full_prompt = f"{system_prompt}\n\n{prompt}\n\n⚠️ 중요: 설명 문장 없이 JSON만 출력하세요." if system_prompt else f"{prompt}\n\n⚠️ 중요: 설명 문장 없이 JSON만 출력하세요."
            response = model.generate_content(full_prompt, generation_config=generation_config)
            raw_text = response.text
            
            if debug:
                print(f"  📝 [{context}] 2차 시도 raw_text 길이: {len(raw_text)}")
            
            result, parse_failure_reason = extract_json_from_text(raw_text, debug=debug)
            failure_reason = parse_failure_reason
            
            if result is not None:
                _llm_cache_set(cache_key, result)
                if debug:
                    print(f"  ✅ [{context}] JSON 파싱 성공 (2차 시도)")
                return result
        except Exception as e:
            error_str = str(e)
            is_429 = "429" in error_str or "RESOURCE_EXHAUSTED" in error_str.upper()
            if is_429:
                print(f"  ⚠️ [{context}] 2차 시도에서도 429 에러, 규칙 기반 fallback으로 전환")
                _llm_cache_set(cache_key, None)
                return None
            print(f"  ⚠️ [{context}] 2차 시도 실패: {e}")
        
        # 3차 시도: REPAIR 모드
        if debug:
            print(f"  🔧 [{context}] JSON 파싱 실패, 3차 시도 (REPAIR 모드)...")
        try:
            repair_prompt = f"""아래 텍스트에서 JSON 부분만 추출하여 유효한 JSON으로 수정하세요.
원문:
{last_raw_text[:2000]}

위 텍스트에서 JSON 부분만 추출하여 완전한 유효한 JSON으로 출력하세요.
설명 문장 없이 JSON만 출력하세요."""
            
            repair_system = system_prompt if system_prompt else "당신은 JSON 수정 전문가입니다. 유효한 JSON만 출력하세요."
            
            model = genai.GenerativeModel(genai_model_name or current_models[0])
            generation_config = genai.types.GenerationConfig(temperature=0.0)
            response = model.generate_content(f"{repair_system}\n\n{repair_prompt}", generation_config=generation_config)
            repaired_text = response.text
            
            if debug:
                print(f"  📝 [{context}] REPAIR 결과 길이: {len(repaired_text)}")
            
            result, parse_failure_reason = extract_json_from_text(repaired_text, debug=debug)
            failure_reason = parse_failure_reason
            
            if result is not None:
                _llm_cache_set(cache_key, result)
                if debug:
                    print(f"  ✅ [{context}] JSON 파싱 성공 (3차 REPAIR)")
                return result
        except Exception as e:
            error_str = str(e)
            is_429 = "429" in error_str or "RESOURCE_EXHAUSTED" in error_str.upper()
            if is_429:
                print(f"  ⚠️ [{context}] REPAIR에서도 429 에러, 규칙 기반 fallback으로 전환")
                _llm_cache_set(cache_key, None)
                return None
            print(f"  ⚠️ [{context}] REPAIR 실패: {e}")
    
    # 모든 시도 실패
    print(f"  ❌ [{context}] JSON 파싱 최종 실패: {failure_reason if failure_reason else '알 수 없음'}")
    _llm_cache_set(cache_key, None)
    return None


# State 정의
class ReportState(TypedDict, total=False):
    """리포트 생성 상태 (Quant-First + Evidence Extraction)"""
    user_id: int
    lifestyle_id: Optional[int]
    survey: Optional[Dict[str, Any]]
    user_profile: Optional[Dict[str, Any]]  # 사용자 기본 정보 파생 지표 (BMI, age_bucket 등)
    active_sections: List[str]
    available_quant_outcomes: Optional[set]  # quant 코퍼스에 실제 존재하는 outcome 목록
    quant_evidence_results: Dict[str, Dict[str, Any]]  # section -> {mode, selected_outcomes, stats_by_outcome, quant_refs}
    section_queries: Dict[str, Dict[str, str]]  # section -> {problem, cause, action} 쿼리
    narrative_evidence: Dict[str, Dict[str, List[EvidenceItem]]]  # section -> {problem, cause, action} -> 근거 리스트
    extracted_claims: Dict[str, Dict[str, List[Dict[str, Any]]]]  # section -> {problem, cause, action} -> claims 리스트
    section_cards: Dict[str, List[Dict[str, Any]]]  # 섹션별 4카드 JSON
    quality_flags: Dict[str, Any]  # 품질 검증 플래그
    final_report: Optional[Dict[str, Any]]
    retry_needed: bool  # 재시도 필요 여부
    retry_sections: List[str]  # 재시도가 필요한 섹션 목록
    retry_count: Dict[str, Any]  # 재시도 횟수 추적 (예: {"validate_cards": {"sleep": 1}, "write_section_cards": {"sleep": 2}})
    situation_text: Optional[str]  # 사용자 참고 상황 (DB 저장 안 함, 프롬프트에만 반영)
    persist_report: bool  # True면 DB/외부 저장, False면 화면 표시용 임시 생성


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
    "hydration_barrier": "decrease_is_improvement",  # TEWL 감소=개선
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

# UI outcomes → narrative 코퍼스 topics 매핑
OUTCOME_TO_NARRATIVE_TOPICS = {
    "wrinkle": ["wrinkle_elasticity", "wrinkle", "skin_aging", "collagen"],
    "elasticity": ["wrinkle_elasticity", "elasticity", "skin_aging", "collagen"],
    "hydration": ["barrier_hydration", "hydration", "skin_barrier", "moisture"],
    "hydration_barrier": ["barrier_hydration", "skin_barrier", "hydration", "moisture"],
    "pigmentation": ["pigmentation", "melanin", "hyperpigmentation", "skin_color"],
    "acne": ["acne", "inflammation", "sebum", "skin_inflammation"],
    "redness": ["redness", "erythema", "inflammation", "skin_inflammation"],
    "general_aging": ["skin_aging", "wrinkle_elasticity", "pigmentation", "general_skin"],
}

# 섹션별 outcome 후보 리스트 (우선순위 순)
SECTION_OUTCOME_CANDIDATES = {
    "sleep": ["hydration_barrier", "wrinkle", "elasticity", "redness"],
    "uv": ["pigmentation", "wrinkle", "elasticity", "redness"],
    "lifestyle": ["acne", "redness", "hydration_barrier", "pigmentation"],
    "activity": ["elasticity", "wrinkle", "general_skin"],
}

# 노드 1: LoadSurvey
def load_survey(state: ReportState) -> ReportState:
    """Lifestyle(DB) 설문만 로드. 리포트 전 구간(요약·본문 카드·RAG)이 동일 설문을 쓴다."""
    user_id = state["user_id"]
    lifestyle_id = state.get("lifestyle_id")
    
    print(f"[LoadSurvey] user_id={user_id}, lifestyle_id={lifestyle_id}")
    
    try:
        survey = get_survey(user_id, lifestyle_id=lifestyle_id)
        if "error" in survey:
            print(f"⚠️ [LoadSurvey] 오류: {survey['error']}")
            return {**state, "survey": None}
        # 일별 스냅샷·HealthData 병합은 하지 않음 (사용자 설문과 리포트 불일치 방지)
        survey = dict(survey)
        print(f"✅ [LoadSurvey] Lifestyle 설문 로드 완료 (lifestyle_id={survey.get('lifestyle_id')})")
        return {**state, "survey": survey}
    except Exception as e:
        print(f"❌ [LoadSurvey] 실패: {e}")
        return {**state, "survey": None}


# 노드 2: PlanSections
def plan_sections(state: ReportState) -> ReportState:
    """생성할 섹션 계획 (lifestyle → smoking/drinking/stress 평탄화)"""
    print("[PlanSections] 섹션 계획 시작")
    survey = state.get("survey")
    if not survey:
        return {**state, "active_sections": []}

    sections = ["summary"]  # 요약 탭은 항상 첫 번째 (플로팅 목표, 피부 타입, 5각형 그래프, 상황 솔루션)

    if survey.get("sleep_hours_weekday") is not None or survey.get("sleep_quality_score") is not None:
        sections.append("sleep")
    if survey.get("uv_exposure_10to16") or survey.get("sunscreen_frequency"):
        sections.append("uv")
    # lifestyle → smoking, drinking, stress를 최상위 섹션으로 (subsections 제거)
    lifestyle_subs = _get_lifestyle_subsection_keys(survey)
    sections.extend(lifestyle_subs)
    if survey.get("aerobic_weekly") or survey.get("resistance_weekly"):
        sections.append("activity")

    print(f"✅ [PlanSections] 섹션 계획 완료: {sections}")
    return {**state, "active_sections": sections}


# 노드 2.5: DeriveUserProfile (신규)
def derive_user_profile(state: ReportState) -> ReportState:
    """사용자 프로필 파생 지표 계산"""
    print("[DeriveUserProfile] 사용자 프로필 계산 시작")
    user_id = state.get("user_id")
    survey = state.get("survey", {})
    
    if not user_id or not survey:
        print("  ⚠️ user_id 또는 survey 없음, 프로필 계산 스킵")
        return {**state, "user_profile": {}}
    
    try:
        user_profile = calculate_user_profile_derived(user_id, survey)
        profile_summary = format_user_profile_for_prompt(user_profile)
        print(f"  ✅ 사용자 프로필 계산 완료: {profile_summary}")
        return {**state, "user_profile": user_profile}
    except Exception as e:
        print(f"  ⚠️ 사용자 프로필 계산 실패: {e}")
        return {**state, "user_profile": {}}


# 노드 4: BuildQueries (카드별 쿼리 생성)
def build_queries(state: ReportState) -> ReportState:
    """섹션별 카드 타입별 검색 쿼리 생성 (quant 결과 + 사용자 정보 반영)"""
    print("[BuildQueries] 카드별 검색 쿼리 생성 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    quant_results = state.get("quant_evidence_results", {})
    user_profile = state.get("user_profile", {})
    
    section_queries = {}
    
    for section in sections:
        if section == "summary":
            continue  # summary는 검색 쿼리 없음
        section_quant = quant_results.get(section, {})
        selected_outcomes = section_quant.get("selected_outcomes", [])
        
        # 사용자 정보 키워드
        user_keywords = []
        if user_profile.get("gender"):
            gender_label = "남성" if user_profile["gender"].lower() in ["male", "m", "남성", "남"] else "여성"
            user_keywords.append(gender_label)
        if user_profile.get("age_bucket"):
            user_keywords.append(user_profile["age_bucket"])
        if user_profile.get("bmi_category") and user_profile.get("bmi_category") in ["과체중", "비만"]:
            user_keywords.append("대사")
        
        # timeframe 키워드 추출
        tf_label = None
        stats = section_quant.get("stats_by_outcome", {})
        if stats:
            for outcome_stats in stats.values():
                if isinstance(outcome_stats, dict) and "timeframe_groups" in outcome_stats:
                    timeframes = list(outcome_stats["timeframe_groups"].keys())[:1]
                    if timeframes:
                        tf_label = timeframe_days_to_label(timeframes[0])
                        break
        
        # outcome 키워드
        outcome_keywords = [OUTCOME_LABELS.get(o, o) for o in selected_outcomes] if selected_outcomes else []
        
        # 카드별 쿼리 생성
        queries_by_card = {}
        
        if section == "goals":
            outcomes = survey.get("outcomes", [])
            outcome_labels = [OUTCOME_LABELS.get(o, o) for o in outcomes]
            queries_by_card["problem"] = f"{' '.join(outcome_labels)} 피부 문제 상태"
            queries_by_card["cause"] = f"{' '.join(outcome_labels)} 원인 메커니즘"
            queries_by_card["action"] = f"{' '.join(outcome_labels)} 개선 방법"
        elif section == "sleep":
            queries_by_card["problem"] = f"수면 부족 단기간 피부 장벽 수분 {' '.join(outcome_keywords)}"
            queries_by_card["cause"] = f"수면 파편화 코르티솔 염증 피부 {' '.join(outcome_keywords)}"
            queries_by_card["action"] = f"수면 연장 개입 시험 피부 {' '.join(outcome_keywords)} {tf_label if tf_label else ''}"
        elif section == "uv":
            queries_by_card["problem"] = f"자외선 노출 사진노화 색소 주름 {' '.join(outcome_keywords)}"
            queries_by_card["cause"] = f"UV 자외선 멜라닌 콜라겐 분해 {' '.join(outcome_keywords)}"
            queries_by_card["action"] = f"선크림 자외선 차단 개입 {' '.join(outcome_keywords)} {tf_label if tf_label else ''}"
        elif section == "lifestyle" or section in LIFESTYLE_SECTIONS:
            queries_by_card["problem"] = f"음주 흡연 스트레스 피부 염증 {' '.join(outcome_keywords)}"
            queries_by_card["cause"] = f"알코올 니코틴 코르티솔 염증 신호 피부 {' '.join(outcome_keywords)}"
            queries_by_card["action"] = f"생활습관 개선 개입 피부 {' '.join(outcome_keywords)} {tf_label if tf_label else ''}"
        elif section == "activity":
            queries_by_card["problem"] = f"운동 부족 대사 피부 탄력 {' '.join(outcome_keywords)}"
            queries_by_card["cause"] = f"신진대사 콜라겐 합성 피부 {' '.join(outcome_keywords)}"
            queries_by_card["action"] = f"운동 개입 피부 건강 {' '.join(outcome_keywords)} {tf_label if tf_label else ''}"
        
        # 사용자 정보 키워드 soft 추가 (각 쿼리에 1개씩만)
        if user_keywords:
            for card_type in queries_by_card:
                if user_keywords and len(user_keywords) > 0:
                    # 첫 번째 키워드만 추가 (너무 길어지지 않게)
                    queries_by_card[card_type] += f" {user_keywords[0]}"
        
        section_queries[section] = queries_by_card
    
    print(f"✅ [BuildQueries] 카드별 쿼리 생성 완료")
    return {**state, "section_queries": section_queries}


def build_dual_queries(section: str, card_type: str, survey: dict, user_profile: dict, 
                       outcome_keywords: List[str] = None) -> List[str]:
    """C. 듀얼 쿼리 생성: 영어 쿼리(필수) + 한국어 보조 쿼리(선택)
    
    Returns:
        [영어 쿼리, 한국어 쿼리(선택)] 리스트
    """
    outcome_keywords = outcome_keywords or []
    
    # 섹션별 영어 키워드 정의
    section_english_keywords = {
        "sleep": ["sleep duration", "sleep deprivation", "skin barrier", "hydration", "inflammation", "cortisol"],
        "uv": ["UV exposure", "photoaging", "sunscreen", "SPF", "wrinkles", "pigmentation", "oxidative stress"],
        "lifestyle": ["psychological stress", "cortisol", "inflammation", "acne", "skin barrier"],
        "activity": ["exercise", "physical activity", "skin elasticity", "collagen", "metabolism"],
    }
    
    # goals 섹션은 outcome 기반
    if section == "goals":
        outcomes = survey.get("outcomes", [])
        outcome_english_map = {
            "wrinkle": ["wrinkle", "skin elasticity", "collagen", "clinical trial"],
            "elasticity": ["skin elasticity", "collagen", "wrinkle", "clinical trial"],
            "hydration": ["skin barrier", "hydration", "moisture", "clinical trial"],
            "hydration_barrier": ["skin barrier", "hydration", "moisture", "clinical trial"],
            "pigmentation": ["pigmentation", "melanin", "hyperpigmentation", "clinical trial"],
            "acne": ["acne", "inflammation", "sebum", "clinical trial"],
            "redness": ["erythema", "redness", "inflammation", "clinical trial"],
        }
        english_keywords = []
        for outcome in outcomes:
            keywords = outcome_english_map.get(outcome, [outcome])
            english_keywords.extend(keywords)
        english_keywords = list(set(english_keywords))[:6]  # 중복 제거, 최대 6개
    else:
        english_keywords = section_english_keywords.get(section, [])
    
    # 카드 타입별 영어 쿼리 구성
    if card_type == "problem":
        if section == "sleep":
            english_query = "sleep deprivation skin barrier hydration inflammation"
        elif section == "uv":
            english_query = "UV exposure photoaging sunscreen wrinkles pigmentation"
        elif section == "lifestyle":
            english_query = "smoking alcohol stress skin inflammation"
        elif section == "activity":
            english_query = "exercise physical activity skin elasticity collagen"
        elif section == "goals":
            english_query = " ".join(english_keywords[:4]) + " skin condition"
        else:
            english_query = " ".join(english_keywords[:4])
    elif card_type == "cause":
        if section == "sleep":
            english_query = "sleep fragmentation cortisol inflammation skin barrier mechanism"
        elif section == "uv":
            english_query = "UV radiation melanin collagen degradation oxidative stress mechanism"
        elif section == "lifestyle":
            english_query = "alcohol nicotine cortisol inflammation skin mechanism"
        elif section == "activity":
            english_query = "metabolism collagen synthesis skin health mechanism"
        elif section == "goals":
            english_query = " ".join(english_keywords[:3]) + " mechanism cause"
        else:
            english_query = " ".join(english_keywords[:3]) + " mechanism"
    else:  # action
        if section == "sleep":
            english_query = "sleep intervention clinical trial skin barrier improvement"
        elif section == "uv":
            english_query = "sunscreen intervention UV protection clinical trial"
        elif section == "lifestyle":
            english_query = "lifestyle intervention stress management skin health"
        elif section == "activity":
            english_query = "exercise intervention skin health clinical trial"
        elif section == "goals":
            english_query = " ".join(english_keywords[:3]) + " intervention treatment"
        else:
            english_query = " ".join(english_keywords[:3]) + " intervention"
    
    # 한국어 쿼리는 기존 build_queries 결과 사용 (선택적)
    korean_query = None  # 필요시 추가
    
    queries = [english_query]
    if korean_query:
        queries.append(korean_query)
    
    return queries


def _qdrant_narrative_items_for_card_type(
    english_query: str,
    korean_query: str,
    topics: Optional[List[str]],
) -> List[Any]:
    """problem/cause/action 한 타입에 대한 Qdrant 검색 체인 (스레드 안전하게 독립 실행)."""
    items: List[Any] = []
    seen_chunk_ids = set()
    try:
        search_input = QdrantSearchInput(
            query=english_query,
            top_k=5,
            topics=topics,
            section_norm=None,
            candidate_k=50,
            min_score=0.2,
        )
        result = qdrant_search(search_input)
        for item in result.items:
            if item.chunk_id not in seen_chunk_ids:
                items.append(item)
                seen_chunk_ids.add(item.chunk_id)
    except Exception:
        pass

    if len(items) == 0 and topics:
        try:
            no_topics = QdrantSearchInput(
                query=english_query,
                top_k=5,
                topics=None,
                section_norm=None,
                candidate_k=50,
                min_score=0.2,
            )
            r2 = qdrant_search(no_topics)
            for item in r2.items:
                if item.chunk_id not in seen_chunk_ids:
                    items.append(item)
                    seen_chunk_ids.add(item.chunk_id)
        except Exception:
            pass

    if len(items) < 3:
        try:
            korean_input = QdrantSearchInput(
                query=korean_query,
                top_k=5,
                topics=topics,
                section_norm=None,
                candidate_k=50,
                min_score=0.2,
            )
            kr = qdrant_search(korean_input)
            for item in kr.items:
                if item.chunk_id not in seen_chunk_ids and len(items) < 5:
                    items.append(item)
                    seen_chunk_ids.add(item.chunk_id)
        except Exception:
            pass

    if len(items) == 0:
        try:
            fallback = QdrantSearchInput(
                query=english_query,
                top_k=10,
                topics=topics,
                section_norm=None,
                candidate_k=80,
                min_score=0.12,
            )
            fb = qdrant_search(fallback)
            for item in fb.items:
                if item.chunk_id not in seen_chunk_ids and len(items) < 5:
                    items.append(item)
                    seen_chunk_ids.add(item.chunk_id)
        except Exception:
            pass

    return items


def _retrieve_section_narrative(section: str, state: ReportState) -> Tuple[str, Dict[str, List]]:
    """단일 섹션 narrative 검색 (병렬 워커용). Returns (section, {problem:[], cause:[], action:[]})."""
    section_queries = state.get("section_queries", {})
    survey = state.get("survey", {})
    queries_by_card = section_queries.get(section, {})
    if not queries_by_card:
        return section, {"problem": [], "cause": [], "action": []}

    # topics 결정
    topics = None
    if section == "goals":
        topics = map_outcomes_to_topics(survey.get("outcomes", []), include_fallback=True)
    elif section == "sleep":
        topics = map_outcomes_to_topics(SECTION_OUTCOME_CANDIDATES.get("sleep", []), include_fallback=True)
    elif section == "uv":
        topics = map_outcomes_to_topics(SECTION_OUTCOME_CANDIDATES.get("uv", []), include_fallback=True)
    elif section in LIFESTYLE_SECTIONS or section == "lifestyle":
        topics = map_outcomes_to_topics(SECTION_OUTCOME_CANDIDATES.get("lifestyle", []), include_fallback=True)
    elif section == "activity":
        topics = ["exercise"]

    section_quant = state.get("quant_evidence_results", {}).get(section, {})
    selected_outcomes = section_quant.get("selected_outcomes", [])
    outcome_keywords = [OUTCOME_LABELS.get(o, o) for o in selected_outcomes] if selected_outcomes else []
    user_profile = state.get("user_profile", {})

    section_results: Dict[str, List] = {
        "problem": [],
        "cause": [],
        "action": [],
    }
    jobs: List[Tuple[str, str, str]] = []
    for card_type in ["problem", "cause", "action"]:
        korean_query = queries_by_card.get(card_type, "")
        if not korean_query:
            continue
        dual_queries = build_dual_queries(
            section, card_type, survey, user_profile, outcome_keywords
        )
        english_query = dual_queries[0] if dual_queries else korean_query
        jobs.append((card_type, korean_query, english_query))

    if jobs:
        max_w = min(3, len(jobs))
        with ThreadPoolExecutor(max_workers=max_w) as pool:
            future_map = {
                pool.submit(
                    _qdrant_narrative_items_for_card_type,
                    eq,
                    kq,
                    topics,
                ): ct
                for ct, kq, eq in jobs
            }
            for fut in as_completed(future_map):
                ct = future_map[fut]
                try:
                    section_results[ct] = fut.result()
                except Exception:
                    section_results[ct] = []

    return section, section_results


# 노드 5: RetrieveNarrativeEvidence (카드별 검색 + fallback + 관측 가능성)
def retrieve_narrative_evidence(state: ReportState) -> ReportState:
    """카드 타입별 원문 근거 검색 — 섹션 간 병렬 + 섹션 내 problem/cause/action 병렬."""
    print("[RetrieveNarrativeEvidence] 카드별 원문 근거 검색 시작 (섹션·카드타입 병렬)")
    sections = state.get("active_sections", [])

    narrative_results = {}
    sections_to_search = [s for s in sections if s != "summary"]
    for s in sections:
        if s == "summary":
            narrative_results[s] = {"problem": [], "cause": [], "action": []}

    if not sections_to_search:
        print("✅ [RetrieveNarrativeEvidence] 완료")
        return {**state, "narrative_evidence": narrative_results}

    max_workers = min(5, len(sections_to_search))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_section = {executor.submit(_retrieve_section_narrative, sec, state): sec for sec in sections_to_search}
        for future in as_completed(future_to_section):
            try:
                sec, section_results = future.result()
                narrative_results[sec] = section_results
                n = sum(len(v) for v in section_results.values() if isinstance(v, list))
                print(f"  ✅ [{sec}] 검색 완료 (총 {n}개)")
            except Exception as e:
                sec = future_to_section[future]
                narrative_results[sec] = {"problem": [], "cause": [], "action": []}
                print(f"  ⚠️ [{sec}] 검색 실패: {e}")

    print("✅ [RetrieveNarrativeEvidence] 완료")
    return {**state, "narrative_evidence": narrative_results}


# 섹션별 카드 타입 키워드 사전 (키워드 우선순위 순)
SECTION_CARD_TYPE_KEYWORDS = {
    "sleep": {
        "problem": ["수면", "불면", "부족", "짧은", "나쁜", "질 낮은", "피로", "졸음", "수면 시간"],
        "cause": ["스트레스", "불규칙", "야근", "수면 환경", "카페인", "알코올", "수면 습관"],
        "action": ["규칙", "수면 시간", "침실 환경", "카페인 제한", "운동", "명상", "수면 위생"]
    },
    "uv": {
        "problem": ["자외선", "UV", "햇빛", "일광", "화상", "색소", "기미", "주근깨", "멜라닌"],
        "cause": ["선크림", "보호", "노출", "야외 활동", "자외선 차단", "UV-A", "UV-B"],
        "action": ["선크림", "자외선 차단", "모자", "긴팔", "그늘", "자외선 지수", "보호"]
    },
    "lifestyle": {
        "problem": ["흡연", "음주", "스트레스", "불규칙", "나쁜 습관", "건강", "피부"],
        "cause": ["담배", "니코틴", "알코올", "압박", "불안", "우울", "생활 패턴"],
        "action": ["금연", "절주", "스트레스 관리", "명상", "운동", "휴식", "건강한 생활"]
    },
    "activity": {
        "problem": ["운동 부족", "활동량", "신체 활동", "근력", "유연성", "체력"],
        "cause": ["좌식", "운동 시간", "일상 활동", "신체 활동 부족"],
        "action": ["유산소", "근력 운동", "스트레칭", "걷기", "달리기", "요가", "운동 계획"]
    },
    "goals": {
        "problem": ["주름", "탄력", "색소", "수분", "장벽", "여드름", "홍조", "노화"],
        "cause": ["나이", "자외선", "건조", "염증", "콜라겐", "엘라스틴", "수분 손실"],
        "action": ["보습", "자외선 차단", "안티에이징", "영양", "관리", "스킨케어", "성분"]
    }
}


def _extract_keyword_based_sentences(text: str, keywords: List[str], max_sentences: int = 2) -> List[str]:
    """키워드 기반으로 문장 추출 (키워드가 포함된 문장 우선)"""
    # 문장 분리 (., !, ? 기준)
    sentences = re.split(r'[.!?]\s+', text)
    sentences = [s.strip() for s in sentences if s.strip()]
    
    if not sentences:
        return []
    
    # 키워드 매칭 점수 계산
    scored_sentences = []
    for sentence in sentences:
        score = 0
        sentence_lower = sentence.lower()
        for keyword in keywords:
            if keyword.lower() in sentence_lower:
                score += 1
        scored_sentences.append((sentence, score))
    
    # 점수 기준 정렬 (높은 점수 우선)
    scored_sentences.sort(key=lambda x: x[1], reverse=True)
    
    # 상위 문장 선택
    selected = []
    for sentence, score in scored_sentences[:max_sentences]:
        if len(sentence) > 30:  # 최소 길이 체크
            selected.append(sentence)
    
    # 키워드 매칭 실패 시 첫 문장 fallback
    if not selected and sentences:
        selected = [sentences[0][:200]]  # 첫 문장 fallback
    
    return selected


# 노드 5.5: ExtractClaims (Evidence Extraction) - LLM 호출 제거, rule-based로 변경
def extract_claims(state: ReportState) -> ReportState:
    """narrative evidence를 구조화된 claims로 변환 (키워드 기반 rule-based)"""
    print("[ExtractClaims] 근거 구조화 시작 (키워드 기반 rule-based, LLM 호출 없음)")
    sections = state.get("active_sections", [])
    narrative_evidence = state.get("narrative_evidence", {})
    survey = state.get("survey", {})
    user_profile = state.get("user_profile", {})
    
    extracted_claims = {}
    
    for section in sections:
        section_evidence = narrative_evidence.get(section, {})
        if not section_evidence:
            extracted_claims[section] = {"problem": [], "cause": [], "action": []}
            continue
        
        # rule-based claims 생성 (키워드 기반)
        section_claims = {}
        for card_type in ["problem", "cause", "action"]:
            evidence_items = section_evidence.get(card_type, [])
            if not evidence_items:
                section_claims[card_type] = []
                continue
            
            # 섹션별 카드 타입 키워드 가져오기 (smoking/drinking/stress → lifestyle)
            kw_section = "lifestyle" if section in LIFESTYLE_SECTIONS else section
            keywords = SECTION_CARD_TYPE_KEYWORDS.get(kw_section, {}).get(card_type, [])
            
            # 키워드 기반 claims 생성
            claims = []
            for item in evidence_items[:2]:  # 최대 2개만
                text = item.text
                
                # 키워드 기반 문장 추출 (1-2개)
                selected_sentences = _extract_keyword_based_sentences(text, keywords, max_sentences=2)
                
                if selected_sentences:
                    # 여러 문장을 하나의 claim으로 결합
                    claim_text = " ".join(selected_sentences)
                    if len(claim_text) > 50:
                        claims.append({
                            "claim": claim_text[:150],
                            "support": [{
                                "chunk_id": item.chunk_id,
                                "support_text": " ".join(selected_sentences)[:200],
                                "why_relevant": f"키워드 기반 추출 ({', '.join(keywords[:3]) if keywords else 'fallback'})"
                            }],
                            "survey_hooks": [],
                            "profile_hooks": []
                        })
            
            section_claims[card_type] = claims[:2]  # 최대 2개
        
        extracted_claims[section] = section_claims
    
    print(f"✅ [ExtractClaims] 완료 (키워드 기반 rule-based, LLM 호출 없음)")
    return {**state, "extracted_claims": extracted_claims}


def _format_survey_data_for_claims(section: str, survey: dict) -> str:
    """claims 추출용 설문 데이터 포맷팅"""
    parts = []
    
    if section == "sleep":
        hours = survey.get('sleep_hours_weekday')
        quality = survey.get('sleep_quality_score')
        if hours is not None:
            parts.append(f"평일 수면 시간: {hours}시간")
        if quality is not None:
            parts.append(f"수면의 질 점수: {quality}/10점")
    elif section == "uv":
        exposure = survey.get('uv_exposure_10to16')
        sunscreen = survey.get('sunscreen_frequency')
        if exposure:
            parts.append(f"자외선 노출 (10-16시): {exposure}")
        if sunscreen:
            parts.append(f"선크림 사용 빈도: {sunscreen}")
    elif section == "lifestyle":
        smoking = survey.get('smoking_status')
        drinking = survey.get('drinking_days_per_week')
        stress = survey.get('stress_score')
        if smoking:
            parts.append(f"흡연 상태: {smoking}")
        if drinking is not None:
            parts.append(f"주당 음주 일수: {drinking}일")
        if stress is not None:
            parts.append(f"스트레스 점수: {stress}/10점")
    elif section == "activity":
        aerobic = survey.get('aerobic_weekly')
        resistance = survey.get('resistance_weekly')
        if aerobic is not None:
            parts.append(f"유산소 운동: {aerobic}회/주")
        if resistance is not None:
            parts.append(f"근력 운동: {resistance}회/주")
    elif section == "goals":
        outcomes = survey.get("outcomes", [])
        if outcomes:
            outcome_labels = [OUTCOME_LABELS.get(o, o) for o in outcomes]
            parts.append(f"피부 고민: {', '.join(outcome_labels)}")
    
    return "\n".join(parts) if parts else "설문 데이터 없음"

def _generate_cards_for_section(
    section: str, state: ReportState
) -> Tuple[str, Dict[str, List[Dict[str, Any]]]]:
    """
    단일 섹션 카드 생성 (병렬 실행용 워커).
    Returns: (section, {key: cards}).
    smoking/drinking/stress는 write_section_cards에서 별도 배치 처리 (generate_lifestyle_cards).
    """
    survey = state.get("survey", {})
    quant_results = state.get("quant_evidence_results", {})
    extracted_claims = state.get("extracted_claims", {})
    user_profile = state.get("user_profile", {})
    cards = generate_section_cards(
        section, survey, quant_results, extracted_claims, user_profile, state,
    )
    return section, {section: cards}


def write_section_cards(state: ReportState) -> ReportState:
    """섹션별 4카드 JSON 생성 (병렬 호출). smoking/drinking/stress는 배치 처리."""
    print("[WriteSectionCards] 카드 생성 시작 (병렬)")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    retry_sections = state.get("retry_sections", [])
    existing_cards = state.get("section_cards", {})

    if retry_sections:
        print(f"  🔄 재시도 섹션: {retry_sections}")
        sections_to_process = retry_sections
        section_cards = existing_cards.copy()
    else:
        sections_to_process = sections
        section_cards: Dict[str, list] = {}

    # smoking/drinking/stress: generate_lifestyle_cards 1회 호출로 배치 생성
    lifestyle_in_sections = [s for s in sections_to_process if s in LIFESTYLE_SECTIONS]
    if lifestyle_in_sections:
        quant_results = state.get("quant_evidence_results", {})
        extracted_claims = state.get("extracted_claims", {})
        user_profile = state.get("user_profile", {})
        lifestyle_result = generate_lifestyle_cards(
            survey, quant_results, extracted_claims, user_profile, state,
        )
        for sub_key in lifestyle_in_sections:
            section_cards[sub_key] = lifestyle_result.get(sub_key, [])
            print(f"  ✅ [{sub_key}] 카드 생성 완료")

    # 나머지 섹션: 병렬 처리 (summary 제외 - assemble_report에서 별도 생성)
    other_sections = [s for s in sections_to_process if s not in LIFESTYLE_SECTIONS and s != "summary"]
    max_workers = max(1, min(len(other_sections), 5))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_section = {
            executor.submit(_generate_cards_for_section, section, state): section
            for section in other_sections
        }
        for future in as_completed(future_to_section):
            section = future_to_section[future]
            try:
                _, result = future.result()
                for key, cards in result.items():
                    section_cards[key] = cards
                print(f"  ✅ [{section}] 카드 생성 완료")
            except Exception as e:
                print(f"  ❌ [{section}] 카드 생성 실패: {e}")
                traceback.print_exc()
                try:
                    _, result = _generate_cards_for_section(section, state)
                    for key, cards in result.items():
                        section_cards[key] = cards
                except Exception as retry_e:
                    print(f"  ❌ [{section}] 재시도도 실패: {retry_e}")

    print(f"\n✅ [WriteSectionCards] 완료")
    print(f"📊 [LLMBudget] 리포트 생성당 총 LLM 호출 횟수: {get_llm_call_count()}회")
    
    # retry_sections 처리 완료 시 플래그 해제
    if retry_sections:
        state["retry_needed"] = False
        state["retry_sections"] = []
    
    # quality_flags 초기화 (이미 있으면 유지)
    quality_flags = state.get("quality_flags", {})
    return {**state, "section_cards": section_cards, "quality_flags": quality_flags}


def _get_lifestyle_subsection_keys(survey: dict) -> List[str]:
    """생활습관 섹션의 하위 섹션 키 목록 반환"""
    subsections = []
    
    smoking = survey.get('smoking_status')
    if smoking and str(smoking).lower() not in ['never', '안', '비흡연', 'never smoked', 'none', '']:
        subsections.append('smoking')
    
    drinking = survey.get('drinking_days_per_week')
    # drinking_days_per_week는 문자열 ('0', '1', '2-3', '4-5', '6-7')
    if drinking is not None and str(drinking) not in ['0', '', 'none']:
        subsections.append('drinking')
    
    stress = survey.get('stress_score')
    if stress is not None and float(stress) > 0:
        subsections.append('stress')
    
    return subsections


def _clean_card_text(text: str) -> tuple[str, bool]:
    """카드 텍스트 공통 후처리: 마크다운 제거 → citation 제거 → 과확신 완화. (text, leaked) 반환."""
    if not text:
        return "", False
    text = strip_markdown(text)
    text, leaked = _remove_citation_leaks(text)
    text = _soften_overconfident_language(text)
    return text, leaked


def _limit_sentences(text: str, max_sentences: int) -> str:
    """문장 수 제한 (문장 단위로 자르기)"""
    if not text:
        return text
    
    # 문장 구분자: . ! ? (한글/영문 모두)
    sentences = re.split(r'([.!?。！？]\s*)', text)
    # 구분자와 문장을 다시 결합
    result_sentences = []
    for i in range(0, len(sentences) - 1, 2):
        if i + 1 < len(sentences):
            result_sentences.append(sentences[i] + sentences[i + 1])
        else:
            result_sentences.append(sentences[i])
    
    # 문장 구분자가 없으면 원본 반환 (잘리지 않게)
    if len(result_sentences) == 0 or (len(result_sentences) == 1 and not re.search(r'[.!?。！？]', text)):
        # 문장 구분자가 없으면 원본 반환 (단, 너무 길면 문자 수로 제한)
        if len(text) > 200:  # action detail이 너무 길면 200자로 제한
            return text[:200].strip() + "..."
        return text
    
    if len(result_sentences) <= max_sentences:
        return text
    
    # max_sentences까지만 유지
    limited = "".join(result_sentences[:max_sentences])
    return limited.strip()


def _remove_citation_leaks(text: str) -> tuple[str, bool]:
    """PMC/논문ID 본문 노출 제거"""
    if not text:
        return text, False
    
    leaked = False
    # 패턴 검사 및 제거
    patterns = [
        (r'PMC\d+', ''),
        (r'PMID\s*:?\s*\d+', ''),
        (r'p\s*[=<>]\s*[\d.]+', ''),
        (r'CI\s*:?\s*\[[^\]]+\]', ''),
        (r'confidence interval', ''),
    ]
    
    cleaned = text
    for pattern, replacement in patterns:
        if re.search(pattern, cleaned, re.IGNORECASE):
            leaked = True
            cleaned = re.sub(pattern, replacement, cleaned, flags=re.IGNORECASE)
    
    # 불필요한 공백 정리
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    
    return cleaned, leaked


def _soften_overconfident_language(text: str) -> str:
    """F. 과확신 표현 완화: "반드시/확실히" 등을 완화된 표현으로 변경"""
    if not text:
        return text
    
    replacements = {
        r'\b반드시\b': '권장됩니다',
        r'\b확실히\b': '가능성이 큽니다',
        r'\b절대적으로\b': '대체로',
        r'\b필수적으로\b': '권장됩니다',
        r'\b100%\b': '높은 확률로',
    }
    
    softened = text
    for pattern, replacement in replacements.items():
        softened = re.sub(pattern, replacement, softened)
    
    return softened


def _build_section_condition(section_key: str, survey: dict) -> str:
    """섹션별 개인화된 condition 문장 생성 (의사가 자연스럽게 요약한 톤)"""
    
    if section_key == "sleep":
        hours = survey.get("sleep_hours_weekday")
        quality = survey.get("sleep_quality_score")
        
        if hours is not None:
            try:
                hours_float = float(hours)
                if hours_float < 6:
                    return f"수면 시간이 부족한 편이므로, 이를 7시간 안팎으로 늘려 유지하면"
                elif 6 <= hours_float < 7:
                    return f"수면 시간을 조금만 늘려 최소 7시간으로 맞춰 유지하면"
                elif hours_float >= 7 and quality is not None:
                    try:
                        quality_float = float(quality)
                        if quality_float < 6:
                            return f"수면 시간은 충분하지만 수면의 질이 낮은 편이므로, 깊은 수면 비율을 높여 유지하면"
                    except (ValueError, TypeError):
                        pass
            except (ValueError, TypeError):
                pass
        
        return "현재의 수면 리듬을 깨지 않도록 유지하면"
    
    elif section_key == "uv":
        exposure = survey.get("uv_exposure_10to16", "")
        sunscreen = survey.get("sunscreen_frequency", "")
        
        sunscreen_low = ["거의 안 씀", "외출 시 가끔", "가끔", "안 씀", "거의 안씀", "never", "안함"]
        sunscreen_str = str(sunscreen).lower() if sunscreen else ""
        if sunscreen and any(low.lower() in sunscreen_str for low in sunscreen_low):
            return f"선크림 사용이 드문 편이므로, 외출할 때마다 바르는 습관을 유지하면"
        
        exposure_str = str(exposure).lower() if exposure else ""
        if exposure and ("거의 매일" in str(exposure) or "매일" in str(exposure) or "daily" in exposure_str):
            return f"낮 시간대 야외 노출이 잦은 편이므로, 이 시간대 노출을 줄여 유지하면"
        
        return "현재의 자외선 관리 습관을 조금만 강화해 유지하면"
    
    elif section_key == "lifestyle":
        smoking = survey.get("smoking_status", "")
        stress = survey.get("stress_score")
        drinking = survey.get("drinking_days_per_week")
        
        # 우선순위 1: 흡연
        if smoking and ("현재" in str(smoking) or "current" in str(smoking).lower()):
            return "흡연 습관이 있으므로, 하루 흡연량을 절반으로 줄여 유지하면"
        
        # 우선순위 2: 스트레스
        if stress is not None:
            try:
                stress_float = float(stress)
                if stress_float >= 7:
                    return f"스트레스 수준이 높은 편이므로, 이를 5점 이하로 낮춰 유지하면"
            except (ValueError, TypeError):
                pass
        
        # 우선순위 3: 음주
        if drinking is not None:
            try:
                drinking_int = int(drinking)
                if drinking_int >= 3:
                    return f"주당 음주 빈도가 높은 편이므로, 이를 주 1일로 줄여 유지하면"
            except (ValueError, TypeError):
                pass
        
        return "현재의 생활습관을 조금만 개선해 유지하면"
    
    elif section_key == "activity":
        aerobic = survey.get("aerobic_weekly")
        resistance = survey.get("resistance_weekly")
        
        # 근력 운동이 0이면 우선
        if resistance is not None:
            try:
                resistance_int = int(resistance)
                if resistance_int == 0:
                    return "근력 운동이 부족한 편이므로, 주 1회 20분만 추가해 유지하면"
            except (ValueError, TypeError):
                pass
        
        # 유산소 운동이 부족하면
        if aerobic is not None:
            try:
                aerobic_int = int(aerobic)
                if aerobic_int < 2:
                    return f"유산소 운동 빈도가 낮은 편이므로, 이를 주 3회로 늘려 유지하면"
            except (ValueError, TypeError):
                pass
        
        return "현재의 운동 패턴을 조금만 강화해 유지하면"
    
    elif section_key == "goals":
        outcomes = survey.get("outcomes", [])
        if outcomes:
            if len(outcomes) <= 2:
                outcome_labels = [OUTCOME_LABELS.get(o, o) for o in outcomes[:2]]
                return f"선택하신 '{', '.join(outcome_labels)}' 목표에 맞춰 관리 습관을 조금만 강화해 유지하면"
            else:
                return "피부 목표 전반을 기준으로 생활습관을 조금만 교정해 유지하면"
        
        return "피부 목표에 맞춰 관리 습관을 조금만 강화해 유지하면"
    
    return "현재의 관리 습관을 유지하면"


def _format_simulation_text(
    section_key: str,
    survey: dict,
    section_quant: dict
) -> tuple[str, dict]:
    """simulation 카드 텍스트 템플릿 강제 생성 (개인화된 condition 포함)"""
    mode = section_quant.get("mode", "estimated")
    stats_by_outcome = section_quant.get("stats_by_outcome", {})
    
    # 개인화된 condition 문장 생성
    condition = _build_section_condition(section_key, survey)
    
    meta = {"mode": mode}
    
    if mode == "grounded" and stats_by_outcome:
        parts: List[str] = []
        visual_list: List[dict] = []
        tf_label = "12주"
        for outcome, stats in stats_by_outcome.items():
            if isinstance(stats, dict) and "timeframe_groups" in stats:
                timeframe_groups = stats["timeframe_groups"]
                if not timeframe_groups:
                    continue
                tf_days = list(timeframe_groups.keys())[0]
                group = timeframe_groups[tf_days]
                tf_label = timeframe_days_to_label(tf_days)
                outcome_label = OUTCOME_LABELS.get(outcome, outcome)
                median = group.get("median", group.get("mean", 0))
                min_val = group.get("min", 0)
                max_val = group.get("max", 0)
                phrase = simulation_effect_phrase(
                    median, min_val, max_val, outcome, quant_mode="grounded"
                )
                parts.append(f"{outcome_label}이(가) {phrase}")
                vm, vl, vh = visual_simulation_chart_values(
                    outcome, median, min_val, max_val, quant_mode="grounded"
                )
                visual_list.append({
                    "outcome_label": outcome_label,
                    "median": round(vm, 1),
                    "min_val": round(vl, 1),
                    "max_val": round(vh, 1),
                    "timeframe_label": tf_label,
                })
                print(f"    📊 [{section_key}] condition=\"{condition}\", tf={tf_label}, outcome={outcome_label}")
        if parts:
            meta["visual_data"] = visual_list
            text = f"{condition} {tf_label} 뒤에는, 연구에서 " + ", ".join(parts) + " 하는 경향이 관찰되었습니다."
            return text, meta
        text = f"{condition} 정량 근거를 바탕으로 예상되는 변화입니다."
        return text, meta
    
    elif mode == "estimated" and "estimated" in stats_by_outcome:
        est = stats_by_outcome["estimated"]
        tf_label = est.get("timeframe_label", "12주")
        
        # 섹션별 outcome_label 추정
        selected_outcomes = section_quant.get("selected_outcomes", [])
        if selected_outcomes:
            # 첫 번째 outcome의 라벨 사용
            outcome_label = OUTCOME_LABELS.get(selected_outcomes[0], "피부 상태")
        else:
            # 섹션별 기본 outcome_label
            section_outcome_map = {
                "sleep": "수분 장벽",
                "uv": "색소침착",
                "lifestyle": "여드름",
                "activity": "탄력",
                "goals": "피부 상태",
            }
            outcome_label = section_outcome_map.get(section_key, "피부 상태")
        
        median = est.get("median", 0)
        min_val = est.get("min", 0)
        max_val = est.get("max", 0)
        outcome_for_polarity = selected_outcomes[0] if selected_outcomes else section_key
        phrase = simulation_effect_phrase(
            median, min_val, max_val, outcome_for_polarity, quant_mode="estimated"
        )
        text = f"{condition} {tf_label} 뒤에는, 정량 근거가 부족해 논문 전반을 바탕으로 보수적으로 보면 {outcome_label}이(가) 대략 {phrase} 경향이 있을 수 있습니다."
        meta["disclaimer_small"] = "이 수치는 개별 연구를 평균낸 값이 아니라, 논문 전반을 바탕으로 한 AI 추정치입니다."
        vm, vl, vh = visual_simulation_chart_values(
            outcome_for_polarity, median, min_val, max_val, quant_mode="estimated"
        )
        meta["visual_data"] = {
            "outcome_label": outcome_label,
            "median": round(vm, 1),
            "min_val": round(vl, 1),
            "max_val": round(vh, 1),
            "timeframe_label": tf_label,
        }
        print(f"    📊 [{section_key}] condition=\"{condition}\", tf={tf_label}, outcome={outcome_label} (estimated)")
        
        return text, meta
    
    text = f"{condition} 정량 근거가 부족하여 정확한 예측이 어렵습니다."
    return text, meta


def _extract_required_survey_values(section: str, survey: dict) -> List[str]:
    """섹션별 필수 설문 값 추출 (SECTION_SURVEY_EXTRACT 기반)"""
    values = []
    if section == "goals":
        outcomes = survey.get("outcomes", [])
        if outcomes:
            values.extend(OUTCOME_LABELS.get(o, o) for o in outcomes)
        return values
    for key, fmt in SECTION_SURVEY_EXTRACT.get(section, []):
        val = survey.get(key)
        if val is None or val == "":
            continue
        values.append(fmt.format(val) if fmt else str(val))
    return values


def _extract_required_profile_values(user_profile: dict) -> List[str]:
    """필수 프로필 값 추출"""
    values = []
    if user_profile.get("gender"):
        gender_label = "남성" if user_profile["gender"].lower() in ["male", "m", "남성", "남"] else "여성"
        values.append(gender_label)
    if user_profile.get("age_bucket"):
        values.append(user_profile["age_bucket"])
    if user_profile.get("bmi_category"):
        values.append(user_profile["bmi_category"])
    return values


def _extract_evidence_keywords_from_quant(quant_results: dict, section: str) -> List[str]:
    """정량 근거에서 키워드 추출"""
    keywords = []
    selected_outcomes = quant_results.get("selected_outcomes", [])
    if selected_outcomes:
        for outcome in selected_outcomes[:2]:  # 최대 2개
            label = OUTCOME_LABELS.get(outcome, outcome)
            keywords.append(label)
    return keywords


def _force_inject_survey_values(text: str, required_values: List[str], section: str) -> str:
    """설문 값이 없으면 강제 삽입 (SECTION_INJECT_SUFFIX 기반)"""
    if not required_values:
        return text
    for value in required_values:
        if value in text:
            return text
    suffix_tpl = SECTION_INJECT_SUFFIX.get(section, " ({0})")
    text += suffix_tpl.format(", ".join(required_values))
    return text


def _force_inject_profile_values(text: str, required_values: List[str], section: str) -> str:
    """프로필 값이 없으면 강제 삽입 (activity 섹션만)"""
    if section != "activity" or not required_values:
        return text
    
    # 이미 포함되어 있는지 확인
    for value in required_values:
        if value in text:
            return text
    
    # 없으면 끝에 추가
    value_str = ", ".join(required_values)
    text += f" ({value_str})"
    return text


def _force_inject_evidence_keywords(text: str, keywords: List[str]) -> str:
    """evidence 키워드가 없으면 강제 삽입"""
    if not keywords:
        return text
    
    # 이미 포함되어 있는지 확인
    for keyword in keywords:
        if keyword in text:
            return text
    
    # 없으면 끝에 추가
    keyword_str = ", ".join(keywords[:2])  # 최대 2개
    text += f" ({keyword_str} 관련)"
    return text


def _postprocess_cards(
    cards: List[Dict[str, Any]], 
    section_quant: dict,
    section_key: str = "",
    survey: dict = None,
    user_profile: dict = None
) -> tuple[List[Dict[str, Any]], Dict[str, bool]]:
    """카드 후처리: 길이 제한, PMC 노출 제거, simulation 템플릿 강제, 설문 수치/키워드/프로필 강제 반영"""
    quality_flags = {"leaked_citation": False}
    processed_cards = []
    
    if survey is None:
        survey = {}
    if user_profile is None:
        user_profile = {}
    
    # 섹션별 필수 키워드 추출
    required_survey_values = _extract_required_survey_values(section_key, survey)
    required_profile_values = _extract_required_profile_values(user_profile)
    required_evidence_keywords = _extract_evidence_keywords_from_quant(section_quant, section_key)
    
    for card in cards:
        card_type = card.get("type")
        processed_card = {**card}
        
        # problem/cause: 공통 텍스트 후처리 + 문장 수 제한
        if card_type in ["problem", "cause"]:
            text, leaked = _clean_card_text(card.get("text", ""))
            if leaked:
                quality_flags["leaked_citation"] = True
            processed_card["text"] = _limit_sentences(text, max_sentences=3)
        
        # simulation: 템플릿 강제 + 공통 후처리 + 문장 수 제한
        elif card_type == "simulation":
            template_text, sim_meta = _format_simulation_text(section_key, survey, section_quant)
            template_text, leaked = _clean_card_text(template_text)
            if leaked:
                quality_flags["leaked_citation"] = True
            processed_card["text"] = _limit_sentences(template_text, max_sentences=4)
            
            # meta 설정
            if "meta" not in processed_card:
                processed_card["meta"] = {}
            processed_card["meta"].update(sim_meta)
            
            # estimated일 때 disclaimer 필수
            if sim_meta.get("mode") == "estimated" and "disclaimer_small" not in processed_card["meta"]:
                processed_card["meta"]["disclaimer_small"] = "정량 근거가 부족해 논문 전반을 바탕으로 AI가 보수적으로 추정한 값입니다. 개인차가 큽니다."
        
        # action: items 3개 강제
        elif card_type == "action":
            items = card.get("items", [])
            if len(items) != 3:
                # 기본 3개로 맞춤
                while len(items) < 3:
                    items.append({"title": "행동", "detail": "분석 중입니다."})
                items = items[:3]
            
            # 각 item의 title/detail: 공통 후처리 → (detail만) 강제 반영 → 문장 제한
            processed_items = []
            for item in items:
                title = item.get("title", "") or "행동"
                detail = item.get("detail", "") or "설명 없음"

                title, leaked1 = _clean_card_text(title)
                detail, leaked2 = _clean_card_text(detail)
                if leaked1 or leaked2:
                    quality_flags["leaked_citation"] = True

                # 설문 수치/키워드/프로필 강제 반영 (action detail에만)
                detail = _force_inject_survey_values(detail, required_survey_values, section_key)
                if section_key == "activity":
                    detail = _force_inject_profile_values(detail, required_profile_values, section_key)
                detail = _force_inject_evidence_keywords(detail, required_evidence_keywords)

                title = _limit_sentences(title, max_sentences=1)
                detail = _limit_sentences(detail, max_sentences=1)

                if not detail or len(detail) < 5:
                    detail, _ = _clean_card_text(item.get("detail", "설명 없음"))
                
                processed_items.append({"title": title, "detail": detail})
            
            processed_card["items"] = processed_items
        
        processed_cards.append(processed_card)
    
    return processed_cards, quality_flags


def _create_default_cards(section: str, survey: dict = None) -> List[Dict[str, Any]]:
    """기본 카드 생성 (fallback) - 개인화된 문장으로 개선"""
    survey = survey or {}
    
    # 섹션별 개인화된 기본 문장 생성
    problem_text = "현재 확보된 근거 범위 내에서 분석 중입니다."
    cause_text = "근거가 부족해 보수적으로 제안합니다."
    action_items = [
        {"title": "행동 1", "detail": "근거 확보 후 제안하겠습니다."},
        {"title": "행동 2", "detail": "근거 확보 후 제안하겠습니다."},
        {"title": "행동 3", "detail": "근거 확보 후 제안하겠습니다."}
    ]
    
    # 설문 데이터 기반 개인화 시도
    if section == "sleep":
        hours = survey.get("sleep_hours_weekday")
        if hours is not None:
            try:
                hours_float = float(hours)
                if hours_float < 7:
                    problem_text = f"수면 패턴을 보면 평일 평균 {hours_float:.1f}시간 정도로 부족한 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
                    cause_text = f"수면 시간 부족으로 인한 피부 회복 저하 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
                    action_items = [
                        {"title": "평일 수면 7시간 맞추기", "detail": "취침 시각을 15~30분씩 앞당기며 누적 시간을 늘리면 회복에 유리합니다."},
                        {"title": "오후 2시 이후 카페인 끊기", "detail": "늦은 카페인은 숙면을 깨기 쉬워 피부 재생 시간이 줄어듭니다."},
                        {"title": "침실 어둡게·서늘하게 유지하기", "detail": "멜라토닌 분비와 숙면에 도움이 되는 환경입니다."}
                    ]
            except (ValueError, TypeError):
                pass
    elif section == "uv":
        sunscreen = survey.get("sunscreen_frequency", "")
        sunscreen_kr = normalize_survey_value(sunscreen, "sunscreen_frequency") if sunscreen else "정보 없음"
        if sunscreen and any(kw in str(sunscreen).lower() for kw in ["never", "안", "거의", "드문"]):
            problem_text = f"선크림 사용이 {sunscreen_kr}인 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
            cause_text = "자외선 노출로 인한 피부 노화 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
            action_items = [
                {"title": "아침 외출 전 선크림 바르기", "detail": "매일 SPF를 바르면 기본 광노화 차단이 유지되기 쉽습니다."},
                {"title": "10~16시 야외 시간 줄이기", "detail": "강한 자외선 시간대는 노출 자체를 줄이면 효과가 큽니다."},
                {"title": "2~3시간마다 차단제 덧바르기", "detail": "땀·마찰로 지워지기 쉬워 재도포가 효과 유지에 필요합니다."}
            ]
    elif section == "lifestyle":
        stress = survey.get("stress_score")
        smoking = survey.get("smoking_status", "")
        smoking_kr = normalize_survey_value(smoking, "smoking_status") if smoking else "정보 없음"
        if stress is not None:
            try:
                stress_float = float(stress)
                if stress_float >= 7:
                    problem_text = f"스트레스 수준이 높은 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
                    cause_text = "높은 스트레스로 인한 피부 염증 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
                    action_items = [
                        {"title": "하루 10분 명상·취미 블록", "detail": "짧은 루틴만으로도 스트레스 호르몬을 낮추는 보고가 있습니다."},
                        {"title": "의도적 휴식 타임 가지기", "detail": "캘린더에 비워 둔 구간이 뇌·피부 회복에 도움이 됩니다."},
                        {"title": "취침·기상 시각 고정하기", "detail": "리듬이 잡히면 장벽 회복과 염증 조절에 유리합니다."}
                    ]
            except (ValueError, TypeError):
                pass
        elif smoking and ("현재" in str(smoking) or "current" in str(smoking).lower()):
            problem_text = f"생활습관을 보면 {smoking_kr}인 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
            cause_text = "흡연으로 인한 피부 노화 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
            action_items = [
                {"title": "하루 흡연량 절반 줄이기", "detail": "양을 줄이면 혈류·산화 스트레스 부담이 함께 줄어드는 경향이 있습니다."},
                {"title": "단계적 금연 일정 잡기", "detail": "작은 목표부터면 지속하기 쉽고 피부에도 변화가 누적되기 쉽습니다."},
                {"title": "흡연 직후 세안·보습하기", "detail": "연기 입자를 빨리 닦아내고 장벽을 덮어 두면 자극 완화에 도움이 됩니다."}
            ]
    elif section == "activity":
        aerobic = survey.get("aerobic_weekly")
        if aerobic is not None:
            try:
                aerobic_int = int(aerobic) if isinstance(aerobic, (int, str)) and str(aerobic).isdigit() else 0
                if aerobic_int < 2:
                    problem_text = "운동 빈도가 낮은 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
                    cause_text = "운동 부족으로 인한 대사 저하 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
                    action_items = [
                        {"title": "주 3회 걷기·조깅 30분", "detail": "가벼운 유산소만으로도 피부 혈류가 좋아진다는 보고가 있습니다."},
                        {"title": "주 2회 근력 운동 넣기", "detail": "근육량·대사에 긍정적이어서 회복력에도 이롭습니다."},
                        {"title": "계단·산책으로 NEAT 늘리기", "detail": "짧은 움직임을 모으면 하루 총 활동량이 누적됩니다."}
                    ]
            except (ValueError, TypeError):
                pass
    
    return [
        {"type": "problem", "title": "현재 상태", "text": problem_text},
        {"type": "cause", "title": "왜 이런 상태인가", "text": cause_text},
        {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": action_items},
        {"type": "simulation", "title": "12주 후 예상 경로", "text": "정량 근거가 부족해 보수적으로 추정한 값입니다.", "meta": {
            "mode": "estimated",
            "disclaimer_small": "정량 근거가 부족해 논문 전반을 바탕으로 AI가 보수적으로 추정한 값입니다. 개인차가 큽니다."
        }}
    ]


# 노드 7: AssembleReport
def assemble_report(state: ReportState) -> ReportState:
    """최종 리포트 조립 (카드 기반). summary는 별도 구조로 생성."""
    print("[AssembleReport] 리포트 조립 시작")
    survey = state.get("survey") or {}
    sections = state.get("active_sections", [])
    section_cards = state.get("section_cards", {})
    quant_results = state.get("quant_evidence_results", {})
    narrative_evidence = state.get("narrative_evidence", {})
    situation_text = state.get("situation_text") or ""

    section_titles = {
        "summary": "요약",
        "goals": "주요 목표 분석 및 개선 방안",
        "sleep": "수면 및 리듬",
        "uv": "자외선 및 노화 관리",
        "smoking": "흡연",
        "drinking": "음주",
        "stress": "스트레스",
        "activity": "활동 및 대사",
    }

    # 리포트 텍스트 수집 (situation_solution LLM용, summary 제외)
    report_sections_parts = []
    for sec in sections:
        if sec == "summary":
            continue
        cards = section_cards.get(sec, [])
        for c in cards if isinstance(cards, list) else []:
            if isinstance(c, dict):
                if c.get("text"):
                    report_sections_parts.append(str(c["text"]))
                for item in c.get("items", []) or []:
                    if isinstance(item, dict) and item.get("detail"):
                        report_sections_parts.append(str(item["detail"]))
    report_sections_text = "\n".join(report_sections_parts)

    # summary 섹션: 별도 구조 (플로팅 목표, 피부 타입, 5각형 그래프, 상황 솔루션)
    from .report_summary import build_summary_data

    summary_data = build_summary_data(survey, situation_text, report_sections_text)
    sections_dict = {}
    sections_dict["summary"] = {
        "title": "요약",
        "is_summary": True,
        "summary_data": summary_data,
        "evidence_refs": {"narrative": [], "quant": []},
    }

    # 섹션별 리포트 구조 생성 (summary 제외)
    for section in sections:
        if section == "summary":
            continue
        cards = _normalize_cards_for_storage(section_cards.get(section, []))
        if not cards:
            continue
        
        # narrative refs 수집 (카드별 구조에서 모든 근거 수집)
        narrative_refs = []
        section_evidence = narrative_evidence.get(section, {})
        if isinstance(section_evidence, dict):
            # 카드별 구조인 경우 (새로운 구조)
            seen_ids = set()  # 중복 제거
            for card_type in ["problem", "cause", "action"]:
                evidence_items = section_evidence.get(card_type, [])
                for item in evidence_items:
                    # EvidenceItem 객체인지 확인 (hasattr로 안전하게 체크)
                    if hasattr(item, 'paper_id') and hasattr(item, 'chunk_id'):
                        item_id = f"{item.paper_id}_{item.chunk_id}"
                        if item_id not in seen_ids:
                            seen_ids.add(item_id)
                            narrative_refs.append({
                                "paper_id": item.paper_id,
                                "chunk_id": item.chunk_id,
                                "title": getattr(item, 'title', None),
                                "pmid": getattr(item, 'pmid', None),
                                "section_norm": getattr(item, 'section_norm', ''),
                                "topics": getattr(item, 'topics', []),
                            })
        elif isinstance(section_evidence, list):
            # 기존 구조 (리스트) - 호환성 유지
            for item in section_evidence:
                # EvidenceItem 객체인지 확인
                if hasattr(item, 'paper_id') and hasattr(item, 'chunk_id'):
                    narrative_refs.append({
                        "paper_id": item.paper_id,
                        "chunk_id": item.chunk_id,
                        "title": getattr(item, 'title', None),
                        "pmid": getattr(item, 'pmid', None),
                        "section_norm": getattr(item, 'section_norm', ''),
                        "topics": getattr(item, 'topics', []),
                    })
        
        # quant refs는 이미 quant_results에 있음
        quant_refs = quant_results.get(section, {}).get("quant_refs", [])

        # 모든 섹션 동일 구조 (subsections 제거, 평탄화)
        sections_dict[section] = {
            "title": section_titles.get(section, section),
            "cards": cards,
            "evidence_refs": {
                "narrative": narrative_refs,
                "quant": quant_refs,
            },
        }
    
    final_report = {
        "user_id": state.get("user_id"),
        "user_name": (state.get("user_profile") or {}).get("nickname") or "사용자",
        "tabs": sections,
        "sections": sections_dict,
        "survey_summary": {
            "outcomes": survey.get("outcomes", []),
            "target_years": 30,
        },
        "generated_at": None,
        # 이미지 생성 정보 포함 (이후 노드에서 채워짐)
        "generated_image_url": state.get("generated_image_url"),
        "generation_status": state.get("generation_status"),
        "image_gen_params": state.get("image_gen_params"),
    }
    
    print(f"✅ [AssembleReport] 완료 - {len(sections_dict)}개 섹션")
    return {**state, "final_report": final_report}


def _normalize_cards_for_storage(raw_cards: Any) -> List[Dict[str, Any]]:
    """
    리포트 저장 직전 카드 스키마 정규화.
    - 카드 스키마(type/text/items/meta) 외 필드는 제거
    - 원문 청크 dict(예: chunk_id/source_snippet) 형태가 섞여 들어오면 저장에서 제외
    """
    if not isinstance(raw_cards, list):
        return []

    normalized: List[Dict[str, Any]] = []
    for card in raw_cards:
        if not isinstance(card, dict):
            continue

        card_type = str(card.get("type", "")).strip()
        if card_type not in {"problem", "cause", "action", "simulation"}:
            continue

        title = str(card.get("title", "")).strip()
        text = str(card.get("text", "")).strip()
        meta = card.get("meta") if isinstance(card.get("meta"), dict) else {}

        if card_type in {"problem", "cause", "simulation"}:
            if not text:
                continue
            out: Dict[str, Any] = {
                "type": card_type,
                "title": title,
                "text": text,
            }
            if meta:
                out["meta"] = meta
            normalized.append(out)
            continue

        # action
        items = card.get("items")
        if not isinstance(items, list):
            continue
        normalized_items: List[Dict[str, str]] = []
        for item in items[:3]:
            if not isinstance(item, dict):
                continue
            item_title = str(item.get("title", "")).strip()
            item_detail = str(item.get("detail", "")).strip()
            if not item_title and not item_detail:
                continue
            normalized_items.append({"title": item_title, "detail": item_detail})

        if not normalized_items:
            continue

        out = {
            "type": "action",
            "title": title,
            "items": normalized_items,
        }
        if meta:
            out["meta"] = meta
        normalized.append(out)

    return normalized


def _collect_narrative_refs(section_evidence) -> List[Dict[str, Any]]:
    """narrative evidence에서 참조 목록 수집"""
    refs = []
    seen_ids = set()

    items_list = []
    if isinstance(section_evidence, dict):
        for card_type in ["problem", "cause", "action"]:
            items_list.extend(section_evidence.get(card_type, []))
    elif isinstance(section_evidence, list):
        items_list = section_evidence

    for item in items_list:
        if hasattr(item, 'paper_id') and hasattr(item, 'chunk_id'):
            item_id = f"{item.paper_id}_{item.chunk_id}"
            if item_id not in seen_ids:
                seen_ids.add(item_id)
                refs.append({
                    "paper_id": item.paper_id,
                    "chunk_id": item.chunk_id,
                    "title": getattr(item, 'title', None),
                    "pmid": getattr(item, 'pmid', None),
                    "section_norm": getattr(item, 'section_norm', ''),
                    "topics": getattr(item, 'topics', []),
                })
    return refs


# ════════════════════════════════════════════════════════════════
#  노드 7.5: GenerateAgingImage
# ════════════════════════════════════════════════════════════════

def generate_aging_image_node(state: ReportState) -> ReportState:
    """
    GPU skin-edit 은 설문 제출 시 /data/skin-edit 에서 수행(/generate 결과를 입력).
    DB Lifestyle.generated_image_url = 설문 기반 skin-edit(리포트 결과 슬라이더 오른쪽·미래얼굴 오른쪽).
    ideal_habits_skin_image_url 은 만점 skin-edit(미래얼굴 왼쪽)이며 리포트 파이프라인·저장에는 넣지 않는다.
    """
    print("---미래 모습 시뮬레이션: DB의 생성 이미지(/generate→skin-edit) 연결---")

    lifestyle_id = state.get("lifestyle_id")
    if not lifestyle_id:
        print("⚠️ [GenerateAgingImage] lifestyle_id 없음")
        return {
            **state,
            "generated_image_url": None,
            "generation_status": "skipped",
            "image_gen_params": {"reason": "no_lifestyle_id"},
        }

    db = SessionLocal()
    try:
        lifestyle = (
            db.query(models.Lifestyle)
            .filter(models.Lifestyle.id == lifestyle_id)
            .first()
        )
        if not lifestyle:
            print("⚠️ [GenerateAgingImage] Lifestyle 레코드 없음")
            return {
                **state,
                "generated_image_url": None,
                "generation_status": "failed",
                "image_gen_params": {"reason": "lifestyle_not_found"},
            }

        url = (lifestyle.generated_image_url or "").strip()
        if url:
            print(f"✅ [GenerateAgingImage] 설문 후 skin-edit 결과 사용 (GPU 재호출 없음): {url}")
            return {
                **state,
                "generated_image_url": url,
                "generation_status": "completed",
                "image_gen_params": {
                    "source": "lifestyle.generated_image_url",
                    "note": "/generate 후 /data/skin-edit 에서만 GPU skin-edit 호출",
                },
            }

        print(
            "⚠️ [GenerateAgingImage] DB에 generated_image_url 없음 "
            "(설문 제출·skin-edit 전에 리포트만 호출했을 수 있음)"
        )
        return {
            **state,
            "generated_image_url": None,
            "generation_status": "pending",
            "image_gen_params": {
                "reason": "no_generated_image_url_in_db",
            },
        }
    finally:
        db.close()


# ════════════════════════════════════════════════════════════════
#  노드 8: SaveReport
# ════════════════════════════════════════════════════════════════

def save_report_node(state: ReportState) -> ReportState:
    """리포트 저장"""
    print("[SaveReport] 리포트 저장 시작")
    if state.get("persist_report") is False:
        print("[SaveReport] persist_report=False 이므로 DB 저장을 건너뜁니다.")
        return state

    user_id = state["user_id"]
    final_report = state.get("final_report")
    survey = state.get("survey", {})
    
    if not final_report:
        print("⚠️ [SaveReport] 저장할 리포트가 없습니다.")
        return state
    
    try:
        # State에서 이미지 관련 데이터를 꺼내서 save_report에 전달
        target_lifestyle_id = state.get("lifestyle_id") or survey.get("lifestyle_id")
        if not target_lifestyle_id:
            print("⚠️ [SaveReport] lifestyle_id가 없어 저장을 중단합니다.")
            return state

        result = save_report(
            user_id, 
            final_report, 
            lifestyle_id=target_lifestyle_id,
            generated_image_url=state.get("generated_image_url"),
            generation_status=state.get("generation_status"),
            image_gen_params=state.get("image_gen_params")
        )
        if "error" in result:
            print(f"⚠️ [SaveReport] 저장 실패: {result['error']}")
        else:
            print(f"✅ [SaveReport] 저장 완료 - report_id: {result.get('report_id')}")
            if result.get("generated_image_url"):
                print(f"   └── 이미지 URL: {result.get('generated_image_url')}")
            final_report["report_id"] = result.get("report_id")
            final_report["generated_at"] = result.get("timestamp")
            final_report["generated_image_url"] = result.get("generated_image_url")
        return {**state, "final_report": final_report}
    except Exception as e:
        print(f"❌ [SaveReport] 저장 실패: {e}")
        return state


# 노드 10: ExportToNotion (신규)
def export_to_notion_node(state: ReportState) -> ReportState:
    """
    완성된 리포트를 Notion MCP를 통해 노션 페이지로 생성
    
    - Notion MCP 도구 호출 (Create Page)
    - 섹션별로 블록 생성 (Append Block Children)
    - 신뢰도 점수와 근거 링크 삽입
    """
    print("[ExportToNotion] Notion 전송 시작")
    if state.get("persist_report") is False:
        print("[ExportToNotion] persist_report=False 이므로 Notion 전송을 건너뜁니다.")
        return state
    
    # Notion 전송 활성화 여부 확인 (환경변수)
    enable_notion_export = os.getenv("ENABLE_NOTION_EXPORT", "false").lower() == "true"
    
    if not enable_notion_export:
        print("⚠️ [ExportToNotion] Notion 전송이 비활성화되어 있습니다 (ENABLE_NOTION_EXPORT=false)")
        return state
    
    final_report = state.get("final_report")
    
    if not final_report:
        print("⚠️ [ExportToNotion] 전송할 리포트가 없습니다.")
        return state
    
    try:
        # 1. Notion으로 전송
        result = export_report_to_notion(final_report)
        
        if result.get("success"):
            print(f"✅ [ExportToNotion] Notion 워크스페이스에 리포트 저장 완료")
            print(f"   - 페이지 ID: {result.get('page_id')}")
            print(f"   - URL: {result.get('url')}")
            
            # final_report에 Notion 정보 추가
            final_report["notion_page_id"] = result.get("page_id")
            final_report["notion_url"] = result.get("url")
            
            return {**state, "final_report": final_report}
        else:
            print(f"⚠️ [ExportToNotion] Notion 전송 실패: {result.get('error')}")
            return state
            
    except Exception as e:
        print(f"❌ [ExportToNotion] 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        return state


# LangGraph 워크플로우 구성
# 노드 6.5: ValidateCards (품질 검증 + 재시도)
def validate_cards(state: ReportState) -> ReportState:
    """생성된 카드 품질 검증 및 재시도 (섹션별 재생성)"""
    print("[ValidateCards] 카드 품질 검증 시작")
    sections = state.get("active_sections", [])
    section_cards = state.get("section_cards", {})
    survey = state.get("survey", {})
    user_profile = state.get("user_profile", {})
    extracted_claims = state.get("extracted_claims", {})
    
    # 재시도 횟수 추적 (섹션별)
    retry_count = state.get("retry_count", {})
    if "validate_cards" not in retry_count:
        retry_count["validate_cards"] = {}
    
    failed_sections = []
    
    for section in sections:
        cards = section_cards.get(section, [])
        if len(cards) != 4:
            print(f"  ⚠️ [{section}] 카드 수 부족 ({len(cards)}개)")
            failed_sections.append(section)
            continue
        
        # 품질 검증
        validation_result = _validate_section_cards(
            section, cards, survey, user_profile, extracted_claims.get(section, {})
        )
        
        if not validation_result["passed"]:
            print(f"  ❌ [{section}] 품질 검증 실패: {validation_result['reason']}")
            failed_sections.append(section)
        else:
            print(f"  ✅ [{section}] 품질 검증 통과")
    
    # 실패한 섹션이 있고 재시도 가능하면 재시도
    if failed_sections:
        if "validate_cards" not in retry_count:
            retry_count["validate_cards"] = {}
        section_retry_count = retry_count.get("validate_cards", {})
        retry_sections_to_add = []
        
        for section in failed_sections:
            count = section_retry_count.get(section, 0)
            if count <= 1:  # 1 이하일 때만 재시도
                print(f"  🔄 [{section}] 재시도 예정 (현재 {count}회)")
                section_retry_count[section] = count + 1
                retry_sections_to_add.append(section)
            else:
                print(f"  ⚠️ [{section}] 재시도 횟수 초과 (현재 {count}회), 현재 상태 유지")
        
        retry_count["validate_cards"] = section_retry_count
        
        # 재시도할 섹션이 있으면 플래그 설정
        if retry_sections_to_add:
            state["retry_needed"] = True
            state["retry_sections"] = retry_sections_to_add
    
    quality_flags = state.get("quality_flags", {})
    quality_flags["validation_passed"] = len(failed_sections) == 0
    
    return {**state, "retry_count": retry_count, "quality_flags": quality_flags}


def _validate_section_cards(
    section: str,
    cards: List[Dict[str, Any]],
    survey: dict,
    user_profile: dict,
    section_claims: dict
) -> Dict[str, Any]:
    """섹션 카드 품질 검증
    
    검증 항목:
    (a) 카드 4장인지 (호출 전에 이미 체크됨)
    (b) problem/cause/action/simulation 타입 존재
    (c) 금지 토큰(PMC/PMID/p=/CI) 누출 여부
    (d) simulation.meta.mode 존재 및 estimated면 disclaimer_small 존재
    (e) 섹션별 필수 설문값이 최소 1개 이상 problem/cause/action/simulation 중 어딘가에 포함
    """
    # (a) 카드 4장인지 - 이미 validate_cards에서 체크됨
    if len(cards) != 4:
        return {"passed": False, "reason": f"카드 수가 4장이 아님 ({len(cards)}장)"}
    
    # (b) problem/cause/action/simulation 타입 존재 확인
    card_types = [card.get("type") for card in cards]
    required_types = {"problem", "cause", "action", "simulation"}
    found_types = set(card_types)
    
    if not required_types.issubset(found_types):
        missing = required_types - found_types
        return {"passed": False, "reason": f"필수 카드 타입 누락: {missing}"}
    
    # (c) 금지 토큰(PMC/PMID/p=/CI) 누출 여부 확인
    for card in cards:
        # 모든 텍스트 수집
        text_parts = [card.get("text", "")]
        for item in card.get("items", []):
            text_parts.append(item.get("title", ""))
            text_parts.append(item.get("detail", ""))
        full_text = " ".join(text_parts)
        
        if _check_forbidden_patterns(full_text):
            return {"passed": False, "reason": f"금지 토큰(PMC/PMID/p=/CI) 누출: {card.get('type')} 카드"}
    
    # (d) simulation.meta.mode 존재 및 estimated면 disclaimer_small 존재 확인
    simulation_cards = [card for card in cards if card.get("type") == "simulation"]
    for sim_card in simulation_cards:
        meta = sim_card.get("meta", {})
        if not meta or "mode" not in meta:
            return {"passed": False, "reason": "simulation 카드에 meta.mode가 없음"}
        
        mode = meta.get("mode")
        if mode == "estimated":
            # estimated면 disclaimer_small이 있어야 함
            disclaimer_small = sim_card.get("disclaimer_small", "")
            if not disclaimer_small or len(disclaimer_small.strip()) == 0:
                return {"passed": False, "reason": "simulation 카드가 estimated인데 disclaimer_small이 없음"}
    
    # (e) 섹션별 필수 설문값이 최소 1개 이상 problem/cause/action/simulation 중 어딘가에 포함
    survey_values_found = False
    all_card_texts = []
    
    for card in cards:
        if card.get("type") in ["problem", "cause", "action", "simulation"]:
            text_parts = [card.get("text", "")]
            for item in card.get("items", []):
                text_parts.append(item.get("title", ""))
                text_parts.append(item.get("detail", ""))
            all_card_texts.append(" ".join(text_parts))
    
    # 모든 카드 텍스트를 합쳐서 설문값 확인
    combined_text = " ".join(all_card_texts)
    if _check_survey_values_in_text(combined_text, section, survey):
        survey_values_found = True
    
    if not survey_values_found:
        return {"passed": False, "reason": "섹션별 필수 설문값이 카드에 반영되지 않음"}
    
    return {"passed": True, "reason": "모든 검증 통과"}


def _check_survey_values_in_text(text: str, section: str, survey: dict) -> bool:
    """텍스트에 설문 값이 자연스럽게 반영되었는지 확인"""
    if section == "goals":
        # outcomes 필드 확인
        outcomes = survey.get("outcomes", [])
        if outcomes and isinstance(outcomes, list):
            # 주요 목표 키워드 확인
            outcome_keywords = {
                "wrinkle": ["주름", "잔주름", "wrinkle"],
                "elasticity": ["탄력", "elasticity"],
                "pigmentation": ["색소", "멜라닌", "기미", "pigmentation"],
                "hydration": ["수분", "보습", "hydration"],
                "barrier": ["장벽", "barrier"],
                "acne": ["여드름", "트러블", "acne"],
                "redness": ["홍조", "붉음", "redness"]
            }
            for outcome in outcomes:
                keywords = outcome_keywords.get(outcome, [])
                if any(kw in text for kw in keywords):
                    return True
        # fallback: "피부" 관련 키워드라도 있으면 통과
        if "피부" in text or "목표" in text:
            return True
    elif section == "sleep":
        hours = survey.get("sleep_hours_weekday")
        if hours is not None:
            # 숫자 또는 자연스러운 표현 확인
            if str(int(hours)) in text or str(hours) in text or "부족" in text or "충분" in text or "수면" in text:
                return True
    elif section == "uv":
        # 자외선 관련 키워드가 있으면 통과
        uv_keywords = ["자외선", "UV", "선크림", "자외선 차단", "광노화", "햇빛"]
        if any(kw in text for kw in uv_keywords):
            return True
        # sunscreen_frequency 값 확인 (더 유연하게)
        sunscreen = survey.get("sunscreen_frequency", "")
        if sunscreen:
            return True
    elif section == "lifestyle":
        stress = survey.get("stress_score")
        if stress is not None:
            if str(int(stress)) in text or "스트레스" in text:
                return True
        # drinking, smoking 관련 키워드
        if "음주" in text or "흡연" in text or "담배" in text or "술" in text:
            return True
    elif section == "activity":
        aerobic = survey.get("aerobic_weekly")
        if aerobic is not None:
            if str(aerobic) in text or "운동" in text or "활동" in text:
                return True
    return False


def _extract_evidence_keywords(section_claims: dict) -> List[str]:
    """claims에서 evidence 키워드 추출"""
    keywords = []
    for card_type in ["problem", "cause", "action"]:
        claims = section_claims.get(card_type, [])
        for claim_data in claims:
            support_list = claim_data.get("support", [])
            for support in support_list:
                support_text = support.get("support_text", "")
                # 키워드 추출 (간단히)
                words = support_text.split()
                keywords.extend([w for w in words if len(w) > 2][:3])  # 최대 3개
    return list(set(keywords))[:10]  # 중복 제거 후 최대 10개


def _check_forbidden_patterns(text: str) -> bool:
    """금지 패턴 확인"""
    forbidden = [
        r'PMC\d+',
        r'PMID\s*:?\s*\d+',
        r'p\s*[=<>]\s*[\d.]+',
        r'CI\s*:?\s*\[',
        r'confidence interval',
    ]
    for pattern in forbidden:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    
    # 과도한 일반론 문구 확인
    generic_phrases = ["~하면 좋습니다", "~하는 것이 중요합니다", "~하는 것을 권장합니다"]
    generic_count = sum(1 for phrase in generic_phrases if phrase in text)
    if generic_count >= 3:
        return True
    
    return False


def _check_overconfident_language(text: str) -> bool:
    """지나친 확신 표현 확인"""
    overconfident = ["반드시", "확실히", "절대적으로", "100%", "필수적으로"]
    for phrase in overconfident:
        if phrase in text:
            return True
    return False


# ── 하위 호환 re-export (report_pipeline에서 파이프라인/진입점 분리) ──
from .report_pipeline import generate_report
