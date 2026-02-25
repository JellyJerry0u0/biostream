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
8. GenerateAgingImage
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

from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

# Tools import
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(backend_dir)
from tools.survey_tool import get_survey
from tools.qdrant_search import qdrant_search
from tools.report_store import save_report
from tools.schemas import QdrantSearchInput, EvidenceItem
from tools.notion_integration import export_report_to_notion
#from tools.notion_integration_mcp import export_report_to_notion
from app.database import get_db
from app.models import User
from datetime import date

# 정량 근거 검색 모듈 import
services_dir = os.path.join(backend_dir, "app", "services")
if services_dir not in sys.path:
    sys.path.append(services_dir)
from quant_evidence_retriever import (
    search_by_outcomes, get_grouped_stats, get_grouped_stats_multi,
    QuantEvidenceCard
)
from app.services.quant_evidence_retriever import (
    get_grouped_stats, get_grouped_stats_multi,
)
from app.services.image_service import image_gen_service

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
)
from .report_llm import get_llm_call_count
from .report_formatters import (
    map_outcomes_to_topics,
    timeframe_days_to_label,
    calculate_user_profile_derived,
    format_user_profile_for_prompt,
    score_outcome_for_selection,
    select_top_timeframes,
    calculate_estimated_stats,
)
from .report_cards import (
    generate_section_cards,
    generate_lifestyle_cards,
    get_lifestyle_subsection_keys,
    create_template_based_subsection_cards,
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

# 표준 timeframe (일 단위)
STANDARD_TIMEFRAMES = {
    "4w": 28.0,
    "12w": 84.0,
    "6m": 182.5,
}


def map_outcomes_to_topics(outcomes: List[str], include_fallback: bool = True) -> List[str]:
    """UI outcomes를 narrative 코퍼스 topics로 변환
    
    Args:
        outcomes: UI outcome 리스트 (예: ["wrinkle", "hydration_barrier"])
        include_fallback: 매핑이 없는 outcome을 그대로 포함할지 여부
    
    Returns:
        narrative topics 리스트 (중복 제거, 순서 유지)
    """
    topics = []
    seen = set()
    
    for outcome in outcomes:
        mapped_topics = OUTCOME_TO_NARRATIVE_TOPICS.get(outcome, [])
        for topic in mapped_topics:
            if topic not in seen:
                topics.append(topic)
                seen.add(topic)
        
        # fallback: 매핑이 없으면 outcome 자체를 포함
        if include_fallback and not mapped_topics and outcome not in seen:
            topics.append(outcome)
            seen.add(outcome)
    
    return topics


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


# ==================== 사용자 기본 정보 파생 지표 계산 ====================

def calculate_user_profile_derived(user_id: int, survey: dict) -> Dict[str, Any]:
    """사용자 기본 정보로부터 파생 지표 계산 (BMI, age_bucket, gender_label 등)"""
    profile = {
        "user_id": user_id,
        "nickname": None,
        "gender": None,
        "age": None,
        "age_bucket": None,
        "height": survey.get("height"),
        "weight": survey.get("weight"),
        "bmi": None,
        "bmi_category": None,
    }
    
    # User 정보 조회
    try:
        db_gen = get_db()
        db = next(db_gen)
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            profile["nickname"] = user.nickname
            profile["gender"] = user.gender
            if user.birthdate:
                today = date.today()
                age = today.year - user.birthdate.year - ((today.month, today.day) < (user.birthdate.month, user.birthdate.day))
                profile["age"] = age
                # 연령대 bucket
                if age < 20:
                    profile["age_bucket"] = "10대"
                elif age < 30:
                    profile["age_bucket"] = "20대"
                elif age < 40:
                    profile["age_bucket"] = "30대"
                elif age < 50:
                    profile["age_bucket"] = "40대"
                elif age < 60:
                    profile["age_bucket"] = "50대"
                else:
                    profile["age_bucket"] = "60대 이상"
        db.close()
    except Exception as e:
        print(f"⚠️ 사용자 정보 조회 실패: {e}")
    
    # BMI 계산
    height = profile.get("height")
    weight = profile.get("weight")
    if height and weight and height > 0:
        height_m = height / 100  # cm -> m
        bmi = weight / (height_m ** 2)
        profile["bmi"] = round(bmi, 1)
        
        # BMI 카테고리
        if bmi < 18.5:
            profile["bmi_category"] = "저체중"
        elif bmi < 23:
            profile["bmi_category"] = "정상"
        elif bmi < 25:
            profile["bmi_category"] = "과체중"
        else:
            profile["bmi_category"] = "비만"
    
    return profile


def format_user_profile_for_prompt(profile: Dict[str, Any]) -> str:
    """프롬프트에 사용할 사용자 프로필 텍스트 포맷팅"""
    parts = []
    
    if profile.get("gender"):
        gender_label = "남성" if profile["gender"].lower() in ["male", "m", "남성", "남"] else "여성"
        parts.append(f"성별: {gender_label}")
    
    if profile.get("age_bucket"):
        parts.append(f"연령대: {profile['age_bucket']}")
    
    if profile.get("bmi") and profile.get("bmi_category"):
        parts.append(f"BMI: {profile['bmi']} ({profile['bmi_category']})")
    
    if not parts:
        return "사용자 기본 정보 없음"
    
    return ", ".join(parts)


def score_outcome_for_selection(stats: Dict[str, Any]) -> float:
    """outcome 선택을 위한 점수 계산"""
    if not stats or not stats.get("timeframe_groups"):
        return 0.0
    
    timeframe_groups = stats["timeframe_groups"]
    max_score = 0.0
    
    for tf_days, group in timeframe_groups.items():
        n_cards = group.get("count", 0)
        if n_cards == 0:
            continue
        
        # p_label 가중치
        p_label_weights = {"strong": 3, "moderate": 2, "weak": 1}
        # 카드들의 p_label 확인 (첫 번째 카드 기준, 실제로는 전체 평균이 더 정확하지만 간단히)
        cards = group.get("cards", [])
        if cards:
            p_label = cards[0].get("p_label", "weak")
            p_weight = p_label_weights.get(p_label, 1)
        else:
            p_weight = 1
        
        # effect_signed_value 극단치 페널티
        median_abs = abs(group.get("median", 0))
        if median_abs > 50:
            continue  # 극단치는 제외
        
        # 점수 = n_cards * p_weight
        score = n_cards * p_weight
        max_score = max(max_score, score)
    
    return max_score


def select_top_timeframes(timeframe_groups: Dict[float, Dict], max_count: int = 2) -> List[float]:
    """대표 timeframe 1-2개 선택 (표준 라벨 우선)"""
    if not timeframe_groups:
        return []
    
    # 표준 timeframe 우선 매핑
    selected = []
    for tf_label, tf_days_std in STANDARD_TIMEFRAMES.items():
        for tf_days in timeframe_groups.keys():
            if abs(tf_days - tf_days_std) < 7:  # 7일 이내 차이
                if tf_days not in selected:
                    selected.append(tf_days)
                    if len(selected) >= max_count:
                        return selected
    
    # 표준 매핑이 부족하면 카드 수 기준으로 추가
    remaining = sorted(
        [d for d in timeframe_groups.keys() if d not in selected],
        key=lambda d: timeframe_groups[d].get("count", 0),
        reverse=True
    )
    
    for tf_days in remaining:
        if len(selected) >= max_count:
            break
        selected.append(tf_days)
    
    return selected[:max_count]


def calculate_estimated_stats(outcome_list: List[str]) -> Optional[Dict[str, Any]]:
    """전체 코퍼스에서 추정치 계산 (fallback) - 안전장치 강화"""
    try:
        # SECTION_OUTCOME_CANDIDATES만 사용 (전체 outcome 무제한 사용 금지)
        stats = get_grouped_stats_multi(outcome_list, exclude_suspicious=True)
        if not stats or not stats.get("timeframe_groups"):
            return None
        
        timeframe_groups = stats["timeframe_groups"]
        
        # 표준 timeframe 우선 선택
        selected_timeframes = select_top_timeframes(timeframe_groups, max_count=1)
        if not selected_timeframes:
            return None
        
        selected_timeframe = selected_timeframes[0]
        group = timeframe_groups[selected_timeframe]
        
        # effect_unit "%"만 사용 (다른 단위 제외)
        cards = group.get("cards", [])
        if not cards:
            return None
        
        # 극단치 클리핑 및 winsorize
        values = [abs(c.get("effect_signed_value", 0)) for c in cards if c.get("effect_unit_filled") == "%"]
        if not values:
            return None
        
        # 절대값 > 50% 제외
        values = [v for v in values if v <= 50]
        if not values:
            return None
        
        # 중앙값 및 범위 계산
        sorted_values = sorted(values)
        n = len(sorted_values)
        median = sorted_values[n // 2] if n % 2 == 1 else (sorted_values[n // 2 - 1] + sorted_values[n // 2]) / 2
        
        # q25, q75 계산
        q25_idx = n // 4
        q75_idx = (3 * n) // 4
        q25 = sorted_values[q25_idx] if q25_idx < n else sorted_values[0]
        q75 = sorted_values[q75_idx] if q75_idx < n else sorted_values[-1]
        
        # 보수적 범위 (클리핑)
        min_val = max(-30, -q75)  # -30% 이하 제외
        max_val = min(30, q75)    # 30% 이상 제외
        
        return {
            "timeframe_days": selected_timeframe,
            "timeframe_label": timeframe_days_to_label(selected_timeframe),
            "median": median,
            "min": min_val,
            "max": max_val,
            "count": len(values),
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


# ════════════════════════════════════════════════════════════════
#  노드 3: PreloadQuantEvidence (헬퍼)
# ════════════════════════════════════════════════════════════════

class _QuantHelper:
    """PreloadQuantEvidence 내부 로직을 깔끔하게 분리하기 위한 네임스페이스"""

    @staticmethod
    def _collect_outcome_scores(outcome_list, search_fn, used_outcomes):
        """outcome 후보들의 점수를 수집"""
        scores = []
        for outcome in outcome_list:
            try:
                stats = search_fn(outcome)
                if stats and stats.get("timeframe_groups"):
                    score = score_outcome_for_selection(stats)
                    if score > 0:
                        scores.append((outcome, stats, score))
            except Exception:
                continue
        return scores

    @staticmethod
    def _select_timeframes_with_dedup(
        timeframe_groups, used_timeframe_labels, max_count=2,
    ):
        """겹침을 최소화하며 timeframe 선택"""
        tf_scores = {}
        for tf_days, group in timeframe_groups.items():
            tf_label = timeframe_days_to_label(tf_days)
            usage = used_timeframe_labels.get(tf_label, 0)
            if usage >= 2:
                continue
            card_count = len(group.get("cards", []))
            tf_scores[tf_days] = card_count / (1 + usage)

        if tf_scores:
            sorted_tfs = sorted(tf_scores.items(), key=lambda x: x[1], reverse=True)
            return [tf for tf, _ in sorted_tfs[:max_count]]
        return select_top_timeframes(timeframe_groups, max_count=max_count)

    @staticmethod
    def _store_outcome_data(
        outcome, stats, section_quant, used_outcomes,
        used_timeframe_labels,
    ):
        """outcome 데이터를 section_quant에 저장"""
        timeframe_groups = stats.get("timeframe_groups", {})
        selected_tfs = _QuantHelper._select_timeframes_with_dedup(
            timeframe_groups, used_timeframe_labels,
        )

        used_outcomes.add(outcome)
        for tf_days in selected_tfs:
            tf_label = timeframe_days_to_label(tf_days)
            used_timeframe_labels[tf_label] = used_timeframe_labels.get(tf_label, 0) + 1

        filtered_groups = {tf: timeframe_groups[tf] for tf in selected_tfs if tf in timeframe_groups}
        section_quant["stats_by_outcome"][outcome] = {**stats, "timeframe_groups": filtered_groups}

        for tf_days in selected_tfs:
            if tf_days in timeframe_groups:
                for card_dict in timeframe_groups[tf_days].get("cards", []):
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

        return len(selected_tfs)


def _preload_goals_quant(survey, section_quant, used_outcomes, used_timeframe_labels):
    """goals 섹션 정량 근거"""
    outcomes = survey.get("outcomes", [])
    outcome_scores = []

    for ui_outcome in outcomes:
        quant_list = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
        if not quant_list:
            continue
        try:
            stats = get_grouped_stats_multi(quant_list, exclude_suspicious=True)
            if stats and stats.get("timeframe_groups"):
                score = score_outcome_for_selection(stats)
                if score > 0:
                    outcome_scores.append((ui_outcome, stats, score))
        except Exception as e:
            print(f"    ⚠️ {ui_outcome} 검색 실패: {e}")

    outcome_scores.sort(key=lambda x: x[2], reverse=True)
    selected = outcome_scores[:2]

    if selected:
        section_quant["mode"] = "grounded"
        section_quant["selected_outcomes"] = [o for o, _, _ in selected]

        for ui_outcome, _, _ in selected:
            for qo in UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, []):
                used_outcomes.add(qo)

        total_tf = 0
        for ui_outcome, stats, _ in selected:
            total_tf += _QuantHelper._store_outcome_data(
                ui_outcome, stats, section_quant, used_outcomes, used_timeframe_labels,
            )
        print(f"    ✅ {len(selected)}개 outcome 선택 → grounded (총 {total_tf}개 timeframe)")


def _preload_section_quant(
    section, survey, section_quant,
    used_outcomes, used_timeframe_labels, available_quant_outcomes,
):
    """일반 섹션 정량 근거"""
    candidates = SECTION_OUTCOME_CANDIDATES.get(section, [])
    outcome_scores = []

    for outcome in candidates:
        try:
            stats = get_grouped_stats(outcome, exclude_suspicious=True)
            if stats and stats.get("timeframe_groups"):
                score = score_outcome_for_selection(stats)
                if score > 0:
                    outcome_scores.append((outcome, stats, score))
        except Exception:
            continue

    # 예상경로 다양화: 섹션 고유 outcome 우선 + 재사용 강한 페널티
    primary = SECTION_PRIMARY_OUTCOME.get(section)
    filtered = []
    for outcome, stats, score in outcome_scores:
        adj = score
        if outcome == primary:
            adj *= 1.4  # 섹션별 1순위 outcome 부스트 (수면→수분, UV→색소 등)
        if outcome in used_outcomes:
            adj *= 0.5  # 다른 섹션에서 이미 사용된 outcome 억제
        filtered.append((outcome, stats, adj))
    filtered.sort(key=lambda x: x[2], reverse=True)
    selected = filtered[:3]  # 예상경로 다양화: 2→3개 outcome 사용

    if selected:
        section_quant["mode"] = "grounded"
        section_quant["selected_outcomes"] = [o for o, _, _ in selected]

        total_tf = 0
        for outcome, stats, _ in selected:
            total_tf += _QuantHelper._store_outcome_data(
                outcome, stats, section_quant, used_outcomes, used_timeframe_labels,
            )
        print(f"    ✅ {len(selected)}개 outcome 선택 → grounded (총 {total_tf}개 timeframe)")
    else:
        # estimated fallback
        outcomes = survey.get("outcomes", [])
        all_quant = []
        for ui_outcome in outcomes:
            all_quant.extend(UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, []))
        filtered_candidates = [c for c in all_quant if c in available_quant_outcomes]
        if filtered_candidates:
            estimated = calculate_estimated_stats(filtered_candidates)
            if estimated:
                section_quant["mode"] = "estimated"
                section_quant["selected_outcomes"] = filtered_candidates[:2]
                section_quant["stats_by_outcome"]["estimated"] = estimated
                print(f"    ⚠️ grounded 없음 → estimated ({estimated['timeframe_label']}, {estimated['median']:.1f}%)")
            else:
                print("    ⚠️ 정량 근거 없음 (estimated 실패)")
        else:
            print("    ⚠️ 정량 근거 없음 (available outcomes 없음)")


def preload_quant_evidence(state: ReportState) -> ReportState:
    """섹션별 정량 근거 먼저 확보 (grounded 또는 estimated)"""
    print("[PreloadQuantEvidence] 정량 근거 확보 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    
    quant_results = {}
    
    # D. Quant fallback 안정화: available outcomes 수집
    available_quant_outcomes = set()
    all_candidate_outcomes = set()
    for section in sections:
        if section == "goals":
            outcomes = survey.get("outcomes", [])
            for ui_outcome in outcomes:
                quant_outcomes = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
                all_candidate_outcomes.update(quant_outcomes)
        else:
            candidates = SECTION_OUTCOME_CANDIDATES.get(section, [])
            all_candidate_outcomes.update(candidates)
    
    # 실제 존재하는 outcome 확인 (샘플링으로 빠르게 체크)
    for outcome in all_candidate_outcomes:
        try:
            stats = get_grouped_stats(outcome, exclude_suspicious=True)
            if stats and stats.get("timeframe_groups"):
                available_quant_outcomes.add(outcome)
        except:
            pass
    
    print(f"  📊 Available quant outcomes: {len(available_quant_outcomes)}개 ({sorted(list(available_quant_outcomes))[:10]})")
    
    # outcome/timeframe 겹침 완화를 위한 추적
    used_outcomes = set()  # 이미 사용된 outcome_mapped
    used_timeframe_labels = {}  # timeframe_label별 사용 횟수
    
    for section in sections:
        print(f"\n  [{section}] 정량 근거 검색 시작")
        section_quant = {
            "mode": "estimated",  # 기본값
            "selected_outcomes": [],
            "stats_by_outcome": {},
            "quant_refs": [],
        }
        
        if section == "goals":
            # goals: 사용자 outcomes 기반 (최대 2개만 선택)
            outcomes = survey.get("outcomes", [])
            outcome_scores = []
            
            for ui_outcome in outcomes:
                quant_outcome_list = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
                if not quant_outcome_list:
                    continue
                
                try:
                    stats = get_grouped_stats_multi(quant_outcome_list, exclude_suspicious=True)
                    if stats and stats.get("timeframe_groups"):
                        score = score_outcome_for_selection(stats)
                        if score > 0:
                            outcome_scores.append((ui_outcome, stats, score))
                except Exception as e:
                    print(f"    ⚠️ {ui_outcome} 검색 실패: {e}")
                    continue
            
            # 점수 기준 정렬하여 상위 2개만 선택
            outcome_scores.sort(key=lambda x: x[2], reverse=True)
            selected_outcomes_data = outcome_scores[:2]  # 최대 2개
            
            if selected_outcomes_data:
                section_quant["mode"] = "grounded"
                section_quant["selected_outcomes"] = [outcome for outcome, _, _ in selected_outcomes_data]
                
                # 선택된 outcome들을 used_outcomes에 반영 (outcome 겹침 완화)
                for ui_outcome, _, _ in selected_outcomes_data:
                    # UI outcome을 quant outcome으로 매핑하여 used_outcomes에 추가
                    quant_outcome_list = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
                    for quant_outcome in quant_outcome_list:
                        used_outcomes.add(quant_outcome)
                
                # 선택된 outcome들의 stats 저장 및 timeframe 필터링
                for ui_outcome, stats, score in selected_outcomes_data:
                    # timeframe 1-2개만 선택
                    timeframe_groups = stats.get("timeframe_groups", {})
                    
                    # timeframe 겹침 완화
                    timeframe_scores = {}
                    for tf_days, group in timeframe_groups.items():
                        tf_label = timeframe_days_to_label(tf_days)
                        usage_count = used_timeframe_labels.get(tf_label, 0)
                        if usage_count >= 2:
                            continue
                        card_count = len(group.get("cards", []))
                        timeframe_scores[tf_days] = card_count / (1 + usage_count)
                    
                    if timeframe_scores:
                        sorted_timeframes = sorted(timeframe_scores.items(), key=lambda x: x[1], reverse=True)
                        selected_timeframes = [tf for tf, _ in sorted_timeframes[:2]]
                    else:
                        selected_timeframes = select_top_timeframes(timeframe_groups, max_count=2)
                    
                    # 사용된 timeframe 추적
                    for tf_days in selected_timeframes:
                        tf_label = timeframe_days_to_label(tf_days)
                        used_timeframe_labels[tf_label] = used_timeframe_labels.get(tf_label, 0) + 1
                    
                    # 선택된 timeframe만 필터링
                    filtered_groups = {tf: timeframe_groups[tf] for tf in selected_timeframes if tf in timeframe_groups}
                    
                    # 필터링된 stats 저장
                    filtered_stats = {
                        **stats,
                        "timeframe_groups": filtered_groups
                    }
                    section_quant["stats_by_outcome"][ui_outcome] = filtered_stats
                    
                    # quant_refs 수집 (선택된 timeframe만)
                    for tf_days in selected_timeframes:
                        if tf_days in timeframe_groups:
                            group = timeframe_groups[tf_days]
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
                
                total_timeframes = sum(len(select_top_timeframes(s.get("timeframe_groups", {}), max_count=2)) for _, s, _ in selected_outcomes_data)
                print(f"    ✅ {len(selected_outcomes_data)}개 outcome 선택 → grounded (총 {total_timeframes}개 timeframe)")
        else:
            # 일반 섹션: 후보 리스트 순회하여 최대 2개 outcome 선택
            candidates = SECTION_OUTCOME_CANDIDATES.get(section, [])
            outcome_scores = []
            
            for outcome in candidates:
                try:
                    stats = get_grouped_stats(outcome, exclude_suspicious=True)
                    if stats and stats.get("timeframe_groups"):
                        score = score_outcome_for_selection(stats)
                        if score > 0:
                            outcome_scores.append((outcome, stats, score))
                except Exception as e:
                    continue
            
            # 점수 기준 정렬하여 상위 1-2개 선택
            outcome_scores.sort(key=lambda x: x[2], reverse=True)
            
            # 겹침 완화: 이미 사용된 outcome은 페널티 적용
            filtered_outcomes = []
            for outcome, stats, score in outcome_scores:
                # 이미 사용된 outcome이면 점수 10% 감소
                if outcome in used_outcomes:
                    adjusted_score = score * 0.9
                    filtered_outcomes.append((outcome, stats, adjusted_score))
                else:
                    filtered_outcomes.append((outcome, stats, score))
            
            # 재정렬
            filtered_outcomes.sort(key=lambda x: x[2], reverse=True)
            selected_outcomes_data = filtered_outcomes[:2]  # 최대 2개
            
            if selected_outcomes_data:
                section_quant["mode"] = "grounded"
                section_quant["selected_outcomes"] = [outcome for outcome, _, _ in selected_outcomes_data]
                
                total_timeframes = 0
                # 선택된 outcome들의 stats 저장 및 timeframe 필터링
                for outcome, stats, score in selected_outcomes_data:
                    # timeframe 1-2개만 선택
                    timeframe_groups = stats.get("timeframe_groups", {})
                    
                    # timeframe 겹침 완화: 이미 많이 사용된 timeframe은 피함
                    timeframe_scores = {}
                    for tf_days, group in timeframe_groups.items():
                        tf_label = timeframe_days_to_label(tf_days)
                        # 이미 사용된 timeframe이면 우선순위 낮춤
                        usage_count = used_timeframe_labels.get(tf_label, 0)
                        if usage_count >= 2:  # 2번 이상 사용되면 피함
                            continue
                        # 카드 수가 많을수록, 사용 횟수가 적을수록 높은 점수
                        card_count = len(group.get("cards", []))
                        timeframe_scores[tf_days] = card_count / (1 + usage_count)
                    
                    if timeframe_scores:
                        # 점수 기준으로 정렬하여 상위 1-2개 선택
                        sorted_timeframes = sorted(timeframe_scores.items(), key=lambda x: x[1], reverse=True)
                        selected_timeframes = [tf for tf, _ in sorted_timeframes[:2]]
                    else:
                        # 겹침이 많아도 최소 1개는 선택
                        selected_timeframes = select_top_timeframes(timeframe_groups, max_count=2)
                    
                    total_timeframes += len(selected_timeframes)
                    
                    # 사용된 outcome과 timeframe 추적
                    used_outcomes.add(outcome)
                    for tf_days in selected_timeframes:
                        tf_label = timeframe_days_to_label(tf_days)
                        used_timeframe_labels[tf_label] = used_timeframe_labels.get(tf_label, 0) + 1
                    
                    # 선택된 timeframe만 필터링
                    filtered_groups = {tf: timeframe_groups[tf] for tf in selected_timeframes if tf in timeframe_groups}
                    
                    # 필터링된 stats 저장
                    filtered_stats = {
                        **stats,
                        "timeframe_groups": filtered_groups
                    }
                    section_quant["stats_by_outcome"][outcome] = filtered_stats
                    
                    # quant_refs 수집 (선택된 timeframe만)
                    for tf_days in selected_timeframes:
                        if tf_days in timeframe_groups:
                            group = timeframe_groups[tf_days]
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
                
                print(f"    ✅ {len(selected_outcomes_data)}개 outcome 선택 → grounded (총 {total_timeframes}개 timeframe)")
            else:
                # D. Quant fallback 안정화: available outcomes만 사용
                outcomes = survey.get("outcomes", [])
                all_quant_candidates = []
                for ui_outcome in outcomes:
                    quant_outcomes = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
                    all_quant_candidates.extend(quant_outcomes)
                filtered_candidates = [c for c in all_quant_candidates if c in available_quant_outcomes]
                if filtered_candidates:
                    estimated = calculate_estimated_stats(filtered_candidates)
                    if estimated:
                        section_quant["mode"] = "estimated"
                        section_quant["selected_outcomes"] = filtered_candidates[:2]  # 상위 2개만
                        section_quant["stats_by_outcome"]["estimated"] = estimated
                        print(f"    ⚠️ grounded 없음 → estimated ({estimated['timeframe_label']}, {estimated['median']:.1f}%)")
                    else:
                        print(f"    ⚠️ 정량 근거 없음 (estimated 실패, narrative만 사용)")
                else:
                    print(f"    ⚠️ 정량 근거 없음 (available outcomes 없음, narrative만 사용)")
        
        quant_results[section] = section_quant
    
    print(f"\n✅ [PreloadQuantEvidence] 완료 - {len(quant_results)}개 섹션")
    return {**state, "quant_evidence_results": quant_results}


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
        elif section == "lifestyle":
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


# 노드 5: RetrieveNarrativeEvidence (카드별 검색 + fallback + 관측 가능성)
def retrieve_narrative_evidence(state: ReportState) -> ReportState:
    """카드 타입별 원문 근거 검색 (narrative only) + fallback 검색 + 상세 로그"""
    print("[RetrieveNarrativeEvidence] 카드별 원문 근거 검색 시작")
    sections = state.get("active_sections", [])
    section_queries = state.get("section_queries", {})
    survey = state.get("survey", {})
    
    narrative_results = {}
    
    for section in sections:
        queries_by_card = section_queries.get(section, {})
        if not queries_by_card:
            narrative_results[section] = {"problem": [], "cause": [], "action": []}
            continue
        
        section_results = {}
        
        # B. Outcome -> Narrative Topics 매핑
        topics = None
        if section == "goals":
            outcomes = survey.get("outcomes", [])
            topics = map_outcomes_to_topics(outcomes, include_fallback=True)
            print(f"  [{section}] UI outcomes {outcomes} → narrative topics {topics}")
        elif section == "sleep":
            # 수면 섹션: outcome 후보 → narrative topics 매핑 (검색 품질 개선)
            section_outcomes = SECTION_OUTCOME_CANDIDATES.get("sleep", [])
            topics = map_outcomes_to_topics(section_outcomes, include_fallback=True)
            print(f"  [{section}] section outcomes {section_outcomes} → narrative topics {topics}")
        elif section == "uv":
            section_outcomes = SECTION_OUTCOME_CANDIDATES.get("uv", [])
            topics = map_outcomes_to_topics(section_outcomes, include_fallback=True)
            print(f"  [{section}] section outcomes {section_outcomes} → narrative topics {topics}")
        elif section == "lifestyle":
            section_outcomes = SECTION_OUTCOME_CANDIDATES.get("lifestyle", [])
            topics = map_outcomes_to_topics(section_outcomes, include_fallback=True)
            print(f"  [{section}] section outcomes {section_outcomes} → narrative topics {topics}")
        elif section == "activity":
            topics = ["exercise"]
        
        # 각 카드 타입별로 검색
        for card_type in ["problem", "cause", "action"]:
            korean_query = queries_by_card.get(card_type, "")
            if not korean_query:
                section_results[card_type] = []
                continue
            
            # C. 듀얼 쿼리: 영어 쿼리 먼저 시도
            section_quant = state.get("quant_evidence_results", {}).get(section, {})
            selected_outcomes = section_quant.get("selected_outcomes", [])
            outcome_keywords = [OUTCOME_LABELS.get(o, o) for o in selected_outcomes] if selected_outcomes else []
            user_profile = state.get("user_profile", {})
            
            dual_queries = build_dual_queries(section, card_type, survey, user_profile, outcome_keywords)
            english_query = dual_queries[0] if dual_queries else korean_query
            
            items = []
            seen_chunk_ids = set()  # 중복 제거
            
            # 1차: 영어 쿼리 + topics로 검색
            try:
                search_input = QdrantSearchInput(
                    query=english_query,
                    top_k=5,
                    topics=topics,
                    section_norm=None,
                    candidate_k=50,
                    min_score=0.2
                )
                result = qdrant_search(search_input)
                for item in result.items:
                    if item.chunk_id not in seen_chunk_ids:
                        items.append(item)
                        seen_chunk_ids.add(item.chunk_id)
                
                if items:
                    top_score = items[0].score if hasattr(items[0], 'score') else None
                    chunk_ids = [item.chunk_id[:20] + "..." if len(item.chunk_id) > 20 else item.chunk_id for item in items[:3]]
                    score_str = f"{top_score:.3f}" if top_score is not None else "N/A"
                    print(f"  [{section}.{card_type}] 1차 영어 검색 (topics 포함): {len(items)}개 (top_score={score_str})")
                    if REPORT_DEBUG:
                        print(f"    📝 영어 쿼리: {english_query[:120]}")
            except Exception as e:
                print(f"  ⚠️ [{section}.{card_type}] 1차 영어 검색 실패: {e}")
            
            # 1.5차: 영어쿼리+topics로 0개일 때, topics=None으로 재시도
            if len(items) == 0 and topics:
                try:
                    search_input_no_topics = QdrantSearchInput(
                        query=english_query,
                        top_k=5,
                        topics=None,  # topic filter 제거
                        section_norm=None,
                        candidate_k=50,
                        min_score=0.2
                    )
                    result_no_topics = qdrant_search(search_input_no_topics)
                    for item in result_no_topics.items:
                        if item.chunk_id not in seen_chunk_ids:
                            items.append(item)
                            seen_chunk_ids.add(item.chunk_id)
                    
                    if items:
                        top_score = items[0].score if hasattr(items[0], 'score') else None
                        score_str = f"{top_score:.3f}" if top_score is not None else "N/A"
                        print(f"  [{section}.{card_type}] 1.5차 영어 검색 (topics=None): {len(items)}개 (top_score={score_str})")
                except Exception as e:
                    print(f"  ⚠️ [{section}.{card_type}] 1.5차 영어 검색 (topics=None) 실패: {e}")
            
            # 2차: 부족하면 한국어 쿼리로 보충
            if len(items) < 3:
                try:
                    korean_input = QdrantSearchInput(
                        query=korean_query,
                        top_k=5,
                        topics=topics,
                        section_norm=None,
                        candidate_k=50,
                        min_score=0.2
                    )
                    korean_result = qdrant_search(korean_input)
                    for item in korean_result.items:
                        if item.chunk_id not in seen_chunk_ids and len(items) < 5:
                            items.append(item)
                            seen_chunk_ids.add(item.chunk_id)
                    
                    if len(items) > 0:
                        print(f"  [{section}.{card_type}] 2차 한국어 보충: 총 {len(items)}개")
                except Exception as e:
                    print(f"  ⚠️ [{section}.{card_type}] 2차 한국어 검색 실패: {e}")
            
            # 3차: 여전히 부족하면 min_score 낮춰 재검색
            if len(items) == 0:
                try:
                    fallback_input = QdrantSearchInput(
                        query=english_query,
                        top_k=10,
                        topics=topics,
                        section_norm=None,
                        candidate_k=80,
                        min_score=0.12  # 0.2 -> 0.12로 완화
                    )
                    fallback_result = qdrant_search(fallback_input)
                    for item in fallback_result.items:
                        if item.chunk_id not in seen_chunk_ids and len(items) < 5:
                            items.append(item)
                            seen_chunk_ids.add(item.chunk_id)
                    
                    if items:
                        top_score = items[0].score if hasattr(items[0], 'score') else None
                        score_str = f"{top_score:.3f}" if top_score is not None else "N/A"
                        print(f"  [{section}.{card_type}] 3차 fallback (min_score=0.12): {len(items)}개 (top_score={score_str})")
                    else:
                        print(f"  [{section}.{card_type}] 모든 검색 실패: 0개")
                except Exception as e:
                    print(f"  ⚠️ [{section}.{card_type}] 3차 fallback 검색 실패: {e}")
            
            section_results[card_type] = items
        
        narrative_results[section] = section_results
    
    print(f"✅ [RetrieveNarrativeEvidence] 완료")
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
            
            # 섹션별 카드 타입 키워드 가져오기
            keywords = SECTION_CARD_TYPE_KEYWORDS.get(section, {}).get(card_type, [])
            
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
    """
    survey = state.get("survey", {})
    quant_results = state.get("quant_evidence_results", {})
    extracted_claims = state.get("extracted_claims", {})
    user_profile = state.get("user_profile", {})
    if section == "lifestyle":
        subsections = get_lifestyle_subsection_keys(survey)
        if subsections:
            lifestyle_result = generate_lifestyle_cards(
                survey, quant_results, extracted_claims, user_profile, state,
            )
            result: Dict[str, List[Dict[str, Any]]] = {}
            for sub_key in subsections:
                result[f"{section}.{sub_key}"] = lifestyle_result.get(sub_key, [])
            result[section] = result.get(f"{section}.{subsections[0]}", [])
            return section, result
        else:
            cards = generate_section_cards(
                section, survey, quant_results, extracted_claims, user_profile, state,
            )
            return section, {section: cards}
    else:
        cards = generate_section_cards(
            section, survey, quant_results, extracted_claims, user_profile, state,
        )
        return section, {section: cards}


def write_section_cards(state: ReportState) -> ReportState:
    """섹션별 4카드 JSON 생성 (병렬 호출)"""
    print("[WriteSectionCards] 카드 생성 시작 (병렬)")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    retry_sections = state.get("retry_sections", [])
    existing_cards = state.get("section_cards", {})
    
    if retry_sections:
        print(f"  🔄 재시도 섹션: {retry_sections}")
        sections_to_process = retry_sections
        section_cards = existing_cards.copy()  # 기존 카드 유지
    else:
        sections_to_process = sections
        section_cards: Dict[str, list] = {}

    max_workers = max(1, min(len(sections_to_process), 5))  # 최대 5개 동시 실행
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_section = {
            executor.submit(_generate_cards_for_section, section, state): section
            for section in sections_to_process
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
                # 실패 시 동기 재시도 (fallback)
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


def _generate_section_cards(
    section: str, 
    survey: dict, 
    quant_results: dict, 
    extracted_claims: dict, 
    user_profile: dict,
    state: ReportState
) -> List[Dict[str, Any]]:
    """일반 섹션의 카드 생성"""
    section_quant = quant_results.get(section, {})
    section_claims = extracted_claims.get(section, {}) if extracted_claims else {}
    
    # 관측 가능성: 로그
    has_claims = any(section_claims.get(card_type) for card_type in ["problem", "cause", "action"]) if section_claims else False
    print(f"  [{section}] has_claims={has_claims}")
    
    if has_claims:
        # 프롬프트 구성 (근거 기반 강화)
        try:
            prompt = _build_card_prompt_enhanced(section, survey, section_quant, section_claims, user_profile)
            if REPORT_DEBUG:
                print(f"    📝 [{section}] enhanced 프롬프트 길이: {len(prompt)}자")
        except Exception as e:
            print(f"    ⚠️ [{section}] enhanced 프롬프트 생성 실패, 기본 프롬프트 사용: {e}")
            has_claims = False  # fallback으로 전환
    
    if not has_claims:
        # claims가 없으면 기존 방식으로 fallback
        print(f"    ⚠️ [{section}] claims가 없어 기본 프롬프트 사용")
        narrative_items_flat = []
        section_evidence = state.get("narrative_evidence", {}).get(section, {})
        if isinstance(section_evidence, dict):
            for card_type in ["problem", "cause", "action"]:
                items = section_evidence.get(card_type, [])
                narrative_items_flat.extend(items[:2])  # 각 카드 타입당 2개씩
        elif isinstance(section_evidence, list):
            narrative_items_flat = section_evidence[:5]
        prompt = _build_card_prompt(section, survey, section_quant, narrative_items_flat)
        if REPORT_DEBUG:
            print(f"    📝 [{section}] 기본 프롬프트 길이: {len(prompt)}자")
    
    system_prompt = """당신은 피부과 전문의입니다. 사용자의 설문 데이터, 정량 근거, 구조화된 주장(claims)을 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.

⚠️ 중요: 설명 문장 없이 JSON만 출력하세요. 다른 텍스트는 절대 포함하지 마세요.

반드시 아래 JSON 구조를 따르세요:
{
  "cards": [
    {"type": "problem", "title": "현재 상태", "text": "정확히 2-3문장만"},
    {"type": "cause", "title": "왜 이런 상태인가", "text": "정확히 2-3문장만"},
    {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": [
      {"title": "Action 1 (1문장)", "detail": "1문장 설명"},
      {"title": "Action 2 (1문장)", "detail": "1문장 설명"},
      {"title": "Action 3 (1문장)", "detail": "1문장 설명"}
    ]},
    {"type": "simulation", "title": "12주 후 예상 경로", "text": "정확히 2-4문장만", "meta": {
      "mode": "grounded" 또는 "estimated",
      "disclaimer_small": "estimated일 때만 필수"
    }}
  ]
}

규칙:
- problem/cause: 각 2-3문장까지만 (더 길면 잘라서 3문장)
- simulation: 4문장 초과 금지
- action items: 정확히 3개, title/detail 각 1문장
- 전문용어는 1회만 (괄호로 쉬운 설명)
- 한국어만 사용
- PMC, PMID, p=, CI 같은 논문 정보는 본문에 절대 포함하지 마세요."""
    
    try:
        context = f"write_section_cards.{section}"
        cards_json = invoke_llm_json(prompt, system_prompt, retry=True, context=context)
        
        if cards_json is None:
            print(f"    ❌ [{section}] 카드 생성 실패 (원인 B: LLM 호출 실패), 기본 카드 생성")
            default_cards = _create_default_cards(section, survey)
            processed_cards, _ = _postprocess_cards(default_cards, section_quant, section, survey, user_profile)
            return processed_cards
        elif "cards" not in cards_json:
            print(f"    ❌ [{section}] 카드 생성 실패 (원인 C: JSON 파싱 실패 - 'cards' 키 없음), 기본 카드 생성")
            if REPORT_DEBUG:
                print(f"    📝 cards_json: {str(cards_json)[:200]}")
            default_cards = _create_default_cards(section, survey)
            processed_cards, _ = _postprocess_cards(default_cards, section_quant, section, survey, user_profile)
            return processed_cards
        else:
            raw_cards = cards_json["cards"]
            if not raw_cards or len(raw_cards) == 0:
                print(f"    ❌ [{section}] 카드 생성 실패 (원인 C: JSON 파싱 실패 - 빈 cards 리스트), 기본 카드 생성")
                default_cards = _create_default_cards(section, survey)
                processed_cards, _ = _postprocess_cards(default_cards, section_quant, section, survey, user_profile)
                return processed_cards
            else:
                # 성공: 후처리
                processed_cards, quality_flags = _postprocess_cards(raw_cards, section_quant, section, survey, user_profile)
                
                if quality_flags.get("leaked_citation"):
                    print(f"    ⚠️ PMC/논문ID 노출 발견 및 제거됨")
                
                print(f"    ✅ [{section}] {len(processed_cards)}개 카드 생성 완료")
                return processed_cards
    except Exception as e:
        import traceback
        print(f"    ❌ [{section}] 카드 생성 실패 (원인 B: 예외 발생): {e}")
        if REPORT_DEBUG:
            print(f"    📝 에러 상세:\n{traceback.format_exc()}")
        default_cards = _create_default_cards(section, survey)
        processed_cards, _ = _postprocess_cards(default_cards, section_quant, section, survey, user_profile)
        return processed_cards


def _generate_subsection_cards(
    section: str,
    subsection_key: str,
    survey: dict,
    quant_results: dict,
    extracted_claims: dict,
    user_profile: dict,
    state: ReportState
) -> List[Dict[str, Any]]:
    """하위 섹션별 카드 생성 (lifestyle의 흡연/음주/스트레스)"""
    section_quant = quant_results.get(section, {})
    section_claims = extracted_claims.get(section, {}) if extracted_claims else {}
    
    # 하위 섹션별 프롬프트 생성
    prompt = _build_subsection_card_prompt(section, subsection_key, survey, section_quant, section_claims, user_profile)
    
    system_prompt = """당신은 피부과 전문의입니다. 사용자의 설문 데이터, 정량 근거, 구조화된 주장(claims)을 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.

⚠️ 중요: 설명 문장 없이 JSON만 출력하세요. 다른 텍스트는 절대 포함하지 마세요.

반드시 아래 JSON 구조를 따르세요:
{
  "cards": [
    {"type": "problem", "title": "현재 상태", "text": "정확히 2-3문장만"},
    {"type": "cause", "title": "왜 이런 상태인가", "text": "정확히 2-3문장만"},
    {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": [
      {"title": "Action 1 (1문장)", "detail": "1문장 설명"},
      {"title": "Action 2 (1문장)", "detail": "1문장 설명"},
      {"title": "Action 3 (1문장)", "detail": "1문장 설명"}
    ]},
    {"type": "simulation", "title": "12주 후 예상 경로", "text": "정확히 2-4문장만", "meta": {
      "mode": "grounded" 또는 "estimated",
      "disclaimer_small": "estimated일 때만 필수"
    }}
  ]
}

규칙:
- problem/cause: 각 2-3문장까지만 (더 길면 잘라서 3문장)
- simulation: 4문장 초과 금지
- action items: 정확히 3개, title/detail 각 1문장
- 전문용어는 1회만 (괄호로 쉬운 설명)
- 한국어만 사용
- PMC, PMID, p=, CI 같은 논문 정보는 본문에 절대 포함하지 마세요."""
    
    try:
        context = f"write_section_cards.{section}.{subsection_key}"
        cards_json = invoke_llm_json(prompt, system_prompt, retry=True, context=context)
        
        if cards_json is None or "cards" not in cards_json or not cards_json.get("cards"):
            print(f"    ❌ [{section}.{subsection_key}] 카드 생성 실패, 기본 카드 생성")
            default_cards = _create_default_subsection_cards(section, subsection_key, survey)
            processed_cards, _ = _postprocess_cards(default_cards, section_quant, section, survey, user_profile)
            return processed_cards
        else:
            raw_cards = cards_json["cards"]
            processed_cards, quality_flags = _postprocess_cards(raw_cards, section_quant, section, survey, user_profile)
            
            if quality_flags.get("leaked_citation"):
                print(f"    ⚠️ PMC/논문ID 노출 발견 및 제거됨")
            
            print(f"    ✅ [{section}.{subsection_key}] {len(processed_cards)}개 카드 생성 완료")
            return processed_cards
    except Exception as e:
        import traceback
        print(f"    ❌ [{section}.{subsection_key}] 카드 생성 실패: {e}")
        if REPORT_DEBUG:
            print(f"    📝 에러 상세:\n{traceback.format_exc()}")
        default_cards = _create_default_subsection_cards(section, subsection_key, survey)
        processed_cards, _ = _postprocess_cards(default_cards, section_quant, section, survey, user_profile)
        return processed_cards


def _build_subsection_card_prompt(
    section: str,
    subsection_key: str,
    survey: dict,
    section_quant: dict,
    section_claims: dict,
    user_profile: dict
) -> str:
    """하위 섹션별 카드 생성 프롬프트"""
    # 하위 섹션별 설문 데이터 추출
    if subsection_key == "smoking":
        smoking = survey.get('smoking_status', 'N/A')
        survey_text = f"""흡연 상태: {smoking}
⚠️ 반드시 흡연 상태를 직접 인용하여 개인화된 리포트를 작성하세요."""
    elif subsection_key == "drinking":
        drinking = survey.get('drinking_days_per_week', 'N/A')
        survey_text = f"""주당 음주 일수: {drinking}일
⚠️ 반드시 음주 빈도를 직접 인용하여 개인화된 리포트를 작성하세요."""
    elif subsection_key == "stress":
        stress = survey.get('stress_score', 'N/A')
        survey_text = f"""스트레스 점수: {stress}/10점
⚠️ 반드시 스트레스 점수를 직접 인용하여 개인화된 리포트를 작성하세요."""
    else:
        survey_text = _format_survey_data(section, survey)
    
    # 사용자 프로필 요약
    profile_text = format_user_profile_for_prompt(user_profile)
    
    # 정량 근거 요약
    quant_text = _format_quant_data(section_quant)
    
    # 하위 섹션별 claims 필터링
    subsection_claims = {}
    for card_type in ["problem", "cause", "action"]:
        claims = section_claims.get(card_type, [])
        # 하위 섹션과 관련된 claims만 필터링 (간단히 키워드로)
        filtered_claims = []
        keywords = {
            "smoking": ["흡연", "담배", "니코틴", "smoking"],
            "drinking": ["음주", "알코올", "술", "drinking", "alcohol"],
            "stress": ["스트레스", "코르티솔", "stress"]
        }
        section_keywords = keywords.get(subsection_key, [])
        for claim in claims:
            claim_text = claim.get("claim", "").lower()
            if any(kw.lower() in claim_text for kw in section_keywords):
                filtered_claims.append(claim)
        subsection_claims[card_type] = filtered_claims
    
    # 구조화된 claims 요약
    claims_texts = []
    for card_type in ["problem", "cause", "action"]:
        claims = subsection_claims.get(card_type, [])
        if claims:
            card_claims = []
            for claim_data in claims[:2]:  # 최대 2개만
                claim_str = claim_data.get("claim", "")
                support_list = claim_data.get("support", [])
                support_texts = [s.get("support_text", "") for s in support_list[:1]]
                card_claims.append(f"- {claim_str}\n  근거: {'; '.join(support_texts)}")
            if card_claims:
                claims_texts.append(f"[{card_type} 카드용 주장]\n" + "\n".join(card_claims))
    
    claims_text = "\n\n".join(claims_texts) if claims_texts else "구조화된 주장 없음"
    
    subsection_titles = {
        "smoking": "흡연",
        "drinking": "음주",
        "stress": "스트레스"
    }
    subsection_title = subsection_titles.get(subsection_key, subsection_key)
    
    return f"""섹션: {section} - {subsection_title}

⚠️ 중요: 반드시 사용자 설문 데이터와 구조화된 주장(claims)을 바탕으로 개인화된 리포트를 작성하세요.
이 하위 섹션은 "{subsection_title}"에만 집중하세요.
일반론적 표현은 절대 사용하지 마세요.
"당신의", "당신은" 같은 2인칭을 반드시 사용하세요.

[사용자 설문 데이터 - 반드시 이 값들을 자연스럽게 요약해 반영하세요]
{survey_text}

[사용자 기본 정보 - 의학적으로 자연스럽게 반영하세요]
{profile_text}

[정량 근거]
{quant_text}

[구조화된 주장(claims) - 이 주장들을 바탕으로 카드 텍스트를 작성하세요]
{claims_text}

⚠️ 각 카드 작성 규칙:
- problem/cause: 위 claims의 "claim"과 "support_text"를 바탕으로 작성하되, 설문 수치를 자연스럽게 요약해 반영
- action: 이 사용자의 {subsection_title} 관련 습관에서 가장 큰 레버에 집중
- 각 카드에 evidence 기반 키워드(근거 support_text에서 추출한 키워드) 최소 1개 포함
- 불확실하면 약하게('가능성이 큽니다/경향이 있습니다') 표현
- 근거에서 말하는 메커니즘/방향성을 1번 이상 언급

위 정보를 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.
각 카드는 사용자 설문 데이터와 구조화된 주장을 바탕으로 개인화되게 작성하세요."""


def _create_template_based_subsection_cards(
    section: str, 
    subsection_key: str, 
    survey: dict, 
    quant_results: dict,
    user_profile: dict
) -> List[Dict[str, Any]]:
    """하위 섹션별 템플릿 기반 카드 생성 (LLM 호출 없음)"""
    section_quant = quant_results.get(section, {})
    cards = _create_default_subsection_cards(section, subsection_key, survey)
    # 후처리 적용
    processed_cards, _ = _postprocess_cards(cards, section_quant, section, survey, user_profile)
    return processed_cards


def _create_default_subsection_cards(section: str, subsection_key: str, survey: dict) -> List[Dict[str, Any]]:
    """하위 섹션별 기본 카드 생성"""
    if subsection_key == "smoking":
        smoking = survey.get('smoking_status', 'N/A')
        problem_text = f"흡연 상태를 보면 {smoking}인 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
        cause_text = "흡연으로 인한 피부 노화 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
        action_items = [
            {"title": "흡연량 줄이기", "detail": "하루 흡연량을 절반으로 줄여보세요."},
            {"title": "금연 계획 세우기", "detail": "단계적으로 금연을 시작하세요."},
            {"title": "흡연 후 피부 관리", "detail": "흡연 후 세안과 보습을 철저히 하세요."}
        ]
    elif subsection_key == "drinking":
        drinking = survey.get('drinking_days_per_week', 0)
        problem_text = f"주당 음주 빈도가 {drinking}일인 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
        cause_text = "과도한 음주로 인한 피부 염증 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
        action_items = [
            {"title": "음주 빈도 줄이기", "detail": "주당 음주 일수를 줄여보세요."},
            {"title": "음주량 조절하기", "detail": "한 번에 마시는 양을 줄이세요."},
            {"title": "음주 후 수분 보충", "detail": "음주 후 충분한 물을 마시세요."}
        ]
    elif subsection_key == "stress":
        stress = survey.get('stress_score', 0)
        problem_text = f"스트레스 수준이 {stress}/10점으로 높은 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
        cause_text = "높은 스트레스로 인한 피부 염증 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
        action_items = [
            {"title": "스트레스 관리 방법 찾기", "detail": "명상, 운동, 취미 등으로 스트레스를 줄이세요."},
            {"title": "충분한 휴식 시간 확보", "detail": "하루 중 휴식 시간을 의도적으로 만드세요."},
            {"title": "수면의 질 개선", "detail": "규칙적인 수면 패턴을 유지하세요."}
        ]
    else:
        problem_text = "현재 확보된 근거 범위 내에서 분석 중입니다."
        cause_text = "근거가 부족해 보수적으로 제안합니다."
        action_items = [
            {"title": "행동 1", "detail": "근거 확보 후 제안하겠습니다."},
            {"title": "행동 2", "detail": "근거 확보 후 제안하겠습니다."},
            {"title": "행동 3", "detail": "근거 확보 후 제안하겠습니다."}
        ]
    
    return [
        {"type": "problem", "title": "현재 상태", "text": problem_text},
        {"type": "cause", "title": "왜 이런 상태인가", "text": cause_text},
        {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": action_items},
        {"type": "simulation", "title": "12주 후 예상 경로", "text": "정량 근거가 부족해 보수적으로 추정한 값입니다.", "meta": {
            "mode": "estimated",
            "disclaimer_small": "정량 근거가 부족해 논문 전반을 바탕으로 AI가 보수적으로 추정한 값입니다. 개인차가 큽니다."
        }}
    ]


def _build_card_prompt_enhanced(section: str, survey: dict, section_quant: dict, section_claims: dict, user_profile: dict) -> str:
    """카드 생성 프롬프트 구성 (근거 기반 강화 버전)"""
    # 설문 데이터 요약
    survey_text = _format_survey_data(section, survey)
    
    # 사용자 프로필 요약
    profile_text = format_user_profile_for_prompt(user_profile)
    
    # 정량 근거 요약
    quant_text = _format_quant_data(section_quant)
    
    # 구조화된 claims 요약
    claims_texts = []
    for card_type in ["problem", "cause", "action"]:
        claims = section_claims.get(card_type, [])
        if claims:
            card_claims = []
            for claim_data in claims[:2]:  # 최대 2개만
                claim_str = claim_data.get("claim", "")
                support_list = claim_data.get("support", [])
                support_texts = [s.get("support_text", "") for s in support_list[:1]]
                card_claims.append(f"- {claim_str}\n  근거: {'; '.join(support_texts)}")
            if card_claims:
                claims_texts.append(f"[{card_type} 카드용 주장]\n" + "\n".join(card_claims))
    
    claims_text = "\n\n".join(claims_texts) if claims_texts else "구조화된 주장 없음"
    
    # 섹션별 개인화 강조
    personalization_note = _get_personalization_note(section, survey)
    
    return f"""섹션: {section}

⚠️ 중요: 반드시 사용자 설문 데이터와 구조화된 주장(claims)을 바탕으로 개인화된 리포트를 작성하세요.
일반론적 표현("수면이 부족하면", "자외선에 노출되면")은 절대 사용하지 마세요.
"당신의", "당신은" 같은 2인칭을 반드시 사용하세요.

{personalization_note}

[사용자 설문 데이터 - 반드시 이 값들을 자연스럽게 요약해 반영하세요]
{survey_text}

[사용자 기본 정보 - 의학적으로 자연스럽게 반영하세요]
{profile_text}
예: "30대 중반 남성에서", "BMI가 높은 편이라", "연령대 특성상..."

[정량 근거]
{quant_text}

[구조화된 주장(claims) - 이 주장들을 바탕으로 카드 텍스트를 작성하세요]
{claims_text}

⚠️ 각 카드 작성 규칙:
- problem/cause: 위 claims의 "claim"과 "support_text"를 바탕으로 작성하되, 설문 수치를 자연스럽게 요약해 반영
- action: 이 사용자 설문 + 신체정보에서 가장 큰 레버 1~2개에 집중 (BMI 높으면 체중·대사 쪽, 수면 짧으면 수면 쪽)
- 각 카드에 evidence 기반 키워드(근거 support_text에서 추출한 키워드) 최소 1개 포함
- 불확실하면 약하게('가능성이 큽니다/경향이 있습니다') 표현
- 근거에서 말하는 메커니즘/방향성(예: 장벽/염증/멜라닌/콜라겐)을 1번 이상 언급

위 정보를 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.
각 카드는 사용자 설문 데이터와 구조화된 주장을 바탕으로 개인화되게 작성하세요."""


def _build_card_prompt(section: str, survey: dict, section_quant: dict, narrative_items: list) -> str:
    """카드 생성 프롬프트 구성"""
    # 설문 데이터 요약 (더 상세하게)
    survey_text = _format_survey_data(section, survey)
    
    # 정량 근거 요약
    quant_text = _format_quant_data(section_quant)
    
    # 원문 근거 요약
    narrative_text = "\n\n".join([item.text[:200] for item in narrative_items[:3]]) if narrative_items else "관련 근거 없음"
    
    # 섹션별 개인화 강조
    personalization_note = _get_personalization_note(section, survey)
    
    return f"""섹션: {section}

⚠️ 중요: 반드시 사용자 설문 데이터를 직접 인용하여 개인화된 리포트를 작성하세요.
일반론적 표현("수면이 부족하면", "자외선에 노출되면")은 절대 사용하지 마세요.
"당신의", "당신은" 같은 2인칭을 반드시 사용하세요.

{personalization_note}

[사용자 설문 데이터 - 반드시 이 값들을 직접 인용하세요]
{survey_text}

[정량 근거]
{quant_text}

[원문 근거 (참고용)]
{narrative_text}

위 정보를 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.
각 카드는 사용자 설문 데이터를 직접 인용하여 개인화되게 작성하세요."""


def _normalize_survey_value(value: Any, field: str) -> str:
    """설문 값을 한국어로 자연스럽게 변환"""
    if value is None or value == 'N/A':
        return "정보 없음"
    
    value_str = str(value).lower().strip()
    
    # 선크림 사용 빈도 변환
    if field == "sunscreen_frequency":
        if any(kw in value_str for kw in ["never", "안", "거의", "드문", "안함", "안 씀", "거의 안"]):
            return "거의 사용하지 않음"
        elif any(kw in value_str for kw in ["가끔", "sometimes", "외출 시"]):
            return "가끔 사용"
        elif any(kw in value_str for kw in ["매일", "daily", "항상", "always"]):
            return "매일 사용"
        elif any(kw in value_str for kw in ["자주", "often", "주 3회"]):
            return "자주 사용"
        else:
            return value_str  # 원본 반환 (이미 한국어일 수 있음)
    
    # 흡연 상태 변환
    elif field == "smoking_status":
        if any(kw in value_str for kw in ["never", "안", "비흡연", "never smoked"]):
            return "비흡연"
        elif any(kw in value_str for kw in ["current", "현재", "흡연", "smoking"]):
            return "현재 흡연"
        elif any(kw in value_str for kw in ["former", "과거", "ex-smoker"]):
            return "과거 흡연"
        else:
            return value_str
    
    # 자외선 노출 변환
    elif field == "uv_exposure_10to16":
        if any(kw in value_str for kw in ["never", "안", "거의", "드문"]):
            return "거의 없음"
        elif any(kw in value_str for kw in ["가끔", "sometimes"]):
            return "가끔"
        elif any(kw in value_str for kw in ["자주", "often", "매일", "daily"]):
            return "자주"
        else:
            return value_str
    
    return str(value)


def _format_survey_data(section: str, survey: dict) -> str:
    """섹션별 설문 데이터 포맷팅 (개인화 강조, 한국어 변환)"""
    if section == "goals":
        outcomes = survey.get("outcomes", [])
        return f"""피부 고민: {', '.join([OUTCOME_LABELS.get(o, o) for o in outcomes])}
⚠️ 이 고민들을 "당신의 {', '.join([OUTCOME_LABELS.get(o, o) for o in outcomes])} 문제"로 직접 언급하세요."""
    elif section == "sleep":
        hours = survey.get('sleep_hours_weekday', 'N/A')
        quality = survey.get('sleep_quality_score', 'N/A')
        return f"""평일 수면 시간: {hours}시간
수면의 질 점수: {quality}/10점
⚠️ 반드시 "당신의 평일 수면은 {hours}시간이며, 수면의 질은 {quality}/10점입니다"로 직접 인용하세요."""
    elif section == "uv":
        exposure = survey.get('uv_exposure_10to16', 'N/A')
        sunscreen = survey.get('sunscreen_frequency', 'N/A')
        exposure_kr = _normalize_survey_value(exposure, "uv_exposure_10to16")
        sunscreen_kr = _normalize_survey_value(sunscreen, "sunscreen_frequency")
        return f"""자외선 노출 (10-16시): {exposure_kr}
선크림 사용 빈도: {sunscreen_kr}
⚠️ 반드시 "자외선 노출이 {exposure_kr}이고, 선크림 사용이 {sunscreen_kr}인 편입니다"처럼 자연스럽게 요약하세요."""
    elif section == "lifestyle":
        smoking = survey.get('smoking_status', 'N/A')
        drinking = survey.get('drinking_days_per_week', 'N/A')
        stress = survey.get('stress_score', 'N/A')
        smoking_kr = _normalize_survey_value(smoking, "smoking_status")
        return f"""흡연 상태: {smoking_kr}
주당 음주 일수: {drinking}일
스트레스 점수: {stress}/10점
⚠️ 반드시 "생활습관을 보면 {smoking_kr}이고, 주당 {drinking}일 음주하며, 스트레스는 {stress}/10점입니다"처럼 자연스럽게 요약하세요."""
    elif section == "activity":
        aerobic = survey.get('aerobic_weekly', 'N/A')
        resistance = survey.get('resistance_weekly', 'N/A')
        return f"""유산소 운동: {aerobic}회/주
근력 운동: {resistance}회/주
⚠️ 반드시 "당신은 유산소 운동을 주 {aerobic}회, 근력 운동을 주 {resistance}회 합니다"로 직접 인용하세요."""
    return ""


def _get_personalization_note(section: str, survey: dict) -> str:
    """섹션별 개인화 강조 노트 (의사가 자연스럽게 요약한 톤)"""
    if section == "sleep":
        hours = survey.get('sleep_hours_weekday', 'N/A')
        return f"""⚠️ 개인화 필수 (의사가 자연스럽게 요약한 톤):
- 설문 데이터({hours}시간)를 반영하되, "의사가 요약한 것처럼" 자연스럽게 표현하세요
- 예: "수면 패턴을 보면 평일 평균 {hours}시간 정도로 부족한 편입니다" (자연스러운 요약)
- X: "당신의 평일 수면은 {hours}시간입니다" (직설적 나열)
- 일반론("수면이 부족하면") 금지"""
    elif section == "uv":
        exposure = survey.get('uv_exposure_10to16', 'N/A')
        sunscreen = survey.get('sunscreen_frequency', 'N/A')
        exposure_kr = _normalize_survey_value(exposure, "uv_exposure_10to16")
        sunscreen_kr = _normalize_survey_value(sunscreen, "sunscreen_frequency")
        return f"""⚠️ 개인화 필수 (의사가 자연스럽게 요약한 톤):
- 설문 데이터를 반영하되, "의사가 요약한 것처럼" 자연스럽게 표현하세요
- 예: "자외선 노출이 {exposure_kr}이고, 선크림 사용이 {sunscreen_kr}인 편입니다" (자연스러운 요약)
- X: "당신은 {exposure}에 자외선에 노출되며, 선크림을 {sunscreen} 사용합니다" (직설적 나열, 영어 단어 사용 금지)
- "never", "안 씀" 같은 영어/직설적 표현 금지, 반드시 한국어로 자연스럽게 요약
- 일반론("자외선에 노출되면") 금지"""
    elif section == "lifestyle":
        smoking = survey.get('smoking_status', 'N/A')
        smoking_kr = _normalize_survey_value(smoking, "smoking_status")
        return f"""⚠️ 개인화 필수 (의사가 자연스럽게 요약한 톤):
- 흡연/음주/스트레스 상태를 반영하되, "의사가 요약한 것처럼" 자연스럽게 표현하세요
- 예: "생활습관을 보면 {smoking_kr}이고, 주당 음주 빈도가 높은 편입니다" (자연스러운 요약)
- X: "당신의 흡연 상태는 {smoking}이며, 주당 5일 음주합니다" (직설적 나열, 영어 단어 사용 금지)
- "never", "안 함" 같은 영어/직설적 표현 금지, 반드시 한국어로 자연스럽게 요약
- 일반론("흡연하면", "음주하면") 금지"""
    elif section == "activity":
        return """⚠️ 개인화 필수 (의사가 자연스럽게 요약한 톤):
- 운동 빈도를 반영하되, "의사가 요약한 것처럼" 자연스럽게 표현하세요
- 예: "운동 패턴을 보면 유산소는 주 1회, 근력은 거의 하지 않는 편입니다" (자연스러운 요약)
- X: "당신은 유산소 운동을 주 1회, 근력 운동을 주 0회 합니다" (직설적 나열)
- 일반론("운동이 중요합니다") 금지"""
    return ""


def _format_quant_data(section_quant: dict) -> str:
    """정량 근거 데이터 포맷팅 (simulation 템플릿용)"""
    mode = section_quant.get("mode", "estimated")
    stats_by_outcome = section_quant.get("stats_by_outcome", {})
    
    if mode == "grounded" and stats_by_outcome:
        lines = []
        for outcome, stats in stats_by_outcome.items():
            if isinstance(stats, dict) and "timeframe_groups" in stats:
                for tf_days, group in stats["timeframe_groups"].items():
                    tf_label = timeframe_days_to_label(tf_days)
                    outcome_label = OUTCOME_LABELS.get(outcome, outcome)
                    median = group.get("median", group.get("mean", 0))
                    min_val = group.get("min", 0)
                    max_val = group.get("max", 0)
                    lines.append(f"{outcome_label}: {tf_label} 유지 시, 연구에서 {outcome_label}이(가) 중앙값 {median:.1f}% 변화(범위 {min_val:.1f}~{max_val:.1f}%)")
        return "\n".join(lines) if lines else "정량 근거 없음"
    elif mode == "estimated" and "estimated" in stats_by_outcome:
        est = stats_by_outcome["estimated"]
        return f"추정치: 정량 근거가 부족해 논문 전반을 바탕으로 보수적으로 추정하면, {est['timeframe_label']}에 {est['min']:.0f}~{est['max']:.0f}% 정도 변화 가능"
    return "정량 근거 없음"


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
        # 첫 번째 outcome/timeframe만 사용 (1-2개 숫자만)
        for outcome, stats in stats_by_outcome.items():
            if isinstance(stats, dict) and "timeframe_groups" in stats:
                timeframe_groups = stats["timeframe_groups"]
                if not timeframe_groups:
                    continue
                
                # 첫 번째 timeframe 선택
                tf_days = list(timeframe_groups.keys())[0]
                group = timeframe_groups[tf_days]
                tf_label = timeframe_days_to_label(tf_days)
                outcome_label = OUTCOME_LABELS.get(outcome, outcome)
                median = group.get("median", group.get("mean", 0))
                min_val = group.get("min", 0)
                max_val = group.get("max", 0)
                
                text = f"{condition} {tf_label} 뒤에는, 연구에서 {outcome_label}이(가) 중앙값 {median:.1f}% 변화(범위 {min_val:.1f}~{max_val:.1f}%)하는 경향이 관찰되었습니다."
                
                # 로그 출력
                print(f"    📊 [{section_key}] condition=\"{condition}\", tf={tf_label}, outcome={outcome_label}")
                
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
        
        text = f"{condition} {tf_label} 뒤에는, 정량 근거가 부족해 논문 전반을 바탕으로 보수적으로 보면 {outcome_label}이(가) 대략 {median:.1f}% 안팎(범위 {min_val:.1f}~{max_val:.1f}%) 변화할 수 있습니다."
        meta["disclaimer_small"] = "이 수치는 개별 연구를 평균낸 값이 아니라, 논문 전반을 바탕으로 한 AI 추정치입니다."
        
        print(f"    📊 [{section_key}] condition=\"{condition}\", tf={tf_label}, outcome={outcome_label} (estimated)")
        
        return text, meta
    
    text = f"{condition} 정량 근거가 부족하여 정확한 예측이 어렵습니다."
    return text, meta


def _extract_required_survey_values(section: str, survey: dict) -> List[str]:
    """섹션별 필수 설문 값 추출"""
    values = []
    if section == "sleep":
        hours = survey.get("sleep_hours_weekday")
        quality = survey.get("sleep_quality_score")
        if hours is not None:
            values.append(f"{hours}시간")
        if quality is not None:
            values.append(f"{quality}/10점")
    elif section == "uv":
        exposure = survey.get("uv_exposure_10to16", "")
        sunscreen = survey.get("sunscreen_frequency", "")
        if exposure:
            values.append(str(exposure))
        if sunscreen:
            values.append(str(sunscreen))
    elif section == "lifestyle":
        stress = survey.get("stress_score")
        drinking = survey.get("drinking_days_per_week")
        smoking = survey.get("smoking_status", "")
        if stress is not None:
            values.append(f"{stress}/10점")
        if drinking is not None:
            values.append(f"{drinking}일")
        if smoking:
            values.append(str(smoking))
    elif section == "activity":
        aerobic = survey.get("aerobic_weekly")
        resistance = survey.get("resistance_weekly")
        if aerobic is not None:
            values.append(f"{aerobic}회")
        if resistance is not None:
            values.append(f"{resistance}회")
    elif section == "goals":
        outcomes = survey.get("outcomes", [])
        if outcomes:
            outcome_labels = [OUTCOME_LABELS.get(o, o) for o in outcomes]
            values.extend(outcome_labels)
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
    """설문 값이 없으면 강제 삽입"""
    if not required_values:
        return text
    
    # 이미 포함되어 있는지 확인
    for value in required_values:
        if value in text:
            return text
    
    # 없으면 끝에 추가
    if section == "sleep":
        value_str = ", ".join(required_values)
        text += f" (현재 평일 수면 {value_str})"
    elif section == "uv":
        value_str = ", ".join(required_values)
        text += f" (선크림 사용: {value_str})"
    elif section == "lifestyle":
        value_str = ", ".join(required_values)
        text += f" (스트레스/음주/흡연: {value_str})"
    elif section == "activity":
        value_str = ", ".join(required_values)
        text += f" (운동 빈도: {value_str})"
    elif section == "goals":
        value_str = ", ".join(required_values)
        text += f" (피부 고민: {value_str})"
    
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
        
        # problem/cause: 문장 수 제한 + 과확신 표현 완화
        if card_type in ["problem", "cause"]:
            text = card.get("text", "")
            text, leaked = _remove_citation_leaks(text)
            if leaked:
                quality_flags["leaked_citation"] = True
            text = _soften_overconfident_language(text)  # F. 과확신 표현 완화
            processed_card["text"] = _limit_sentences(text, max_sentences=3)
        
        # simulation: 템플릿 강제 + 문장 수 제한
        elif card_type == "simulation":
            # 템플릿으로 강제 생성 (section_key, survey 전달)
            template_text, sim_meta = _format_simulation_text(section_key, survey, section_quant)
            template_text, leaked = _remove_citation_leaks(template_text)
            if leaked:
                quality_flags["leaked_citation"] = True
            template_text = _soften_overconfident_language(template_text)  # F. 과확신 표현 완화
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
            
            # 각 item의 title/detail 길이 제한 및 PMC 제거
            processed_items = []
            for item in items:
                title = item.get("title", "")
                detail = item.get("detail", "")
                
                # 빈 값 체크
                if not title:
                    title = "행동"
                if not detail:
                    detail = "설명 없음"
                
                title, leaked1 = _remove_citation_leaks(title)
                detail, leaked2 = _remove_citation_leaks(detail)
                if leaked1 or leaked2:
                    quality_flags["leaked_citation"] = True
                
                # F. 과확신 표현 완화
                title = _soften_overconfident_language(title)
                detail = _soften_overconfident_language(detail)
                
                # 설문 수치/키워드/프로필 강제 반영 (action은 detail에만)
                detail = _force_inject_survey_values(detail, required_survey_values, section_key)
                if section_key == "activity":  # activity는 프로필도 반영
                    detail = _force_inject_profile_values(detail, required_profile_values, section_key)
                detail = _force_inject_evidence_keywords(detail, required_evidence_keywords)
                
                # title/detail은 1문장으로 제한하되, 문장 구분자가 없으면 전체 반환
                title = _limit_sentences(title, max_sentences=1)
                detail = _limit_sentences(detail, max_sentences=1)
                
                # detail이 비어있거나 너무 짧으면 원본 detail 사용 (잘리지 않게)
                if not detail or len(detail) < 5:
                    detail = item.get("detail", "설명 없음")
                    detail, _ = _remove_citation_leaks(detail)
                
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
                        {"title": "수면 시간을 7시간 이상으로 늘리기", "detail": "평일 수면 시간을 조금씩 늘려보세요."},
                        {"title": "수면 전 카페인 섭취 줄이기", "detail": "오후 2시 이후 카페인 섭취를 피하세요."},
                        {"title": "수면 환경 개선", "detail": "어두운 방, 적정 온도 유지하세요."}
                    ]
            except (ValueError, TypeError):
                pass
    elif section == "uv":
        sunscreen = survey.get("sunscreen_frequency", "")
        sunscreen_kr = _normalize_survey_value(sunscreen, "sunscreen_frequency") if sunscreen else "정보 없음"
        if sunscreen and any(kw in str(sunscreen).lower() for kw in ["never", "안", "거의", "드문"]):
            problem_text = f"선크림 사용이 {sunscreen_kr}인 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
            cause_text = "자외선 노출로 인한 피부 노화 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
            action_items = [
                {"title": "외출 시 선크림 사용하기", "detail": "매일 외출 전 선크림을 바르세요."},
                {"title": "자외선 강한 시간대 피하기", "detail": "오전 10시~오후 4시 야외 활동을 줄이세요."},
                {"title": "선크림 재도포하기", "detail": "2~3시간마다 선크림을 다시 바르세요."}
            ]
    elif section == "lifestyle":
        stress = survey.get("stress_score")
        smoking = survey.get("smoking_status", "")
        smoking_kr = _normalize_survey_value(smoking, "smoking_status") if smoking else "정보 없음"
        if stress is not None:
            try:
                stress_float = float(stress)
                if stress_float >= 7:
                    problem_text = f"스트레스 수준이 높은 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
                    cause_text = "높은 스트레스로 인한 피부 염증 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
                    action_items = [
                        {"title": "스트레스 관리 방법 찾기", "detail": "명상, 운동, 취미 등으로 스트레스를 줄이세요."},
                        {"title": "충분한 휴식 시간 확보", "detail": "하루 중 휴식 시간을 의도적으로 만드세요."},
                        {"title": "수면의 질 개선", "detail": "규칙적인 수면 패턴을 유지하세요."}
                    ]
            except (ValueError, TypeError):
                pass
        elif smoking and ("현재" in str(smoking) or "current" in str(smoking).lower()):
            problem_text = f"생활습관을 보면 {smoking_kr}인 편입니다. 현재 확보된 근거 범위 내에서 분석 중입니다."
            cause_text = "흡연으로 인한 피부 노화 가능성이 있습니다. 근거가 부족해 보수적으로 제안합니다."
            action_items = [
                {"title": "흡연량 줄이기", "detail": "하루 흡연량을 절반으로 줄여보세요."},
                {"title": "금연 계획 세우기", "detail": "단계적으로 금연을 시작하세요."},
                {"title": "흡연 후 피부 관리", "detail": "흡연 후 세안과 보습을 철저히 하세요."}
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
                        {"title": "주 3회 이상 유산소 운동", "detail": "걷기, 조깅, 자전거 등 주 3회 이상 하세요."},
                        {"title": "근력 운동 추가하기", "detail": "주 2회 이상 근력 운동을 추가하세요."},
                        {"title": "일상 활동량 늘리기", "detail": "계단 이용, 짧은 산책 등으로 활동량을 늘리세요."}
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
        
        # lifestyle 섹션은 하위 섹션으로 분리
        if section == "lifestyle":
            # 하위 섹션별 카드 가져오기 (예: "lifestyle.smoking", "lifestyle.drinking")
            lifestyle_subsection_keys = _get_lifestyle_subsection_keys(survey)
            subsections = []
            
            for subsection_key in lifestyle_subsection_keys:
                subsection_cards_key = f"{section}.{subsection_key}"
                subsection_cards = section_cards.get(subsection_cards_key, [])
                
                if subsection_cards:
                    subsection_titles = {
                        "smoking": "흡연",
                        "drinking": "음주",
                        "stress": "스트레스"
                    }
                    subsections.append({
                        "key": subsection_key,
                        "title": subsection_titles.get(subsection_key, subsection_key),
                        "cards": subsection_cards,
                        "evidence_refs": {
                            "narrative": narrative_refs,
                            "quant": quant_refs,
                        }
                    })
            
            # 하위 섹션이 없으면 일반 섹션으로 처리
            if subsections:
                sections_dict[section] = {
                    "title": section_titles.get(section, section),
                    "subsections": subsections,
                    "evidence_refs": {
                        "narrative": narrative_refs,
                        "quant": quant_refs,
                    }
                }
            else:
                # 하위 섹션이 없으면 일반 카드 사용
                sections_dict[section] = {
                    "title": section_titles.get(section, section),
                    "cards": cards,
                    "evidence_refs": {
                        "narrative": narrative_refs,
                        "quant": quant_refs,
                    }
                }
        else:
            sections_dict[section] = {
                "title": section_titles.get(section, section),
                "cards": cards,
                "evidence_refs": {
                    "narrative": narrative_refs,
                    "quant": quant_refs,
                }
            }
    
    final_report = {
        "user_id": state.get("user_id"),
        "user_name": (state.get("user_profile") or {}).get("nickname") or "사용자",
        "tabs": sections,
        "sections": sections_dict,
        "survey_summary": {
            "outcomes": survey.get("outcomes", []),
            "target_years": survey.get("target_years", 30),
        },
        "generated_at": None,
        # 이미지 생성 정보 포함 (이후 노드에서 채워짐)
        "generated_image_url": state.get("generated_image_url"),
        "generation_status": state.get("generation_status"),
        "image_gen_params": state.get("image_gen_params"),
    }
    
    print(f"✅ [AssembleReport] 완료 - {len(sections_dict)}개 섹션")
    return {**state, "final_report": final_report}


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
    사용자의 습관 데이터를 바탕으로 미래 이미지를 생성하는 노드
    """
    print("---미래 모습 시뮬레이션 생성 시작---")
    
    # 1. 서비스 호출에 필요한 데이터 추출
    lifestyle_id = state.get("lifestyle_id")
    survey = state.get("survey", {})
    user_profile = state.get("user_profile", {})
    
    # survey에서 성별과 목표 년수 추출
    gender = user_profile.get("gender") or survey.get("gender", "unknown")
    target_years = survey.get("target_years", 30)
    
    # 습관 데이터 추출 (survey 전체를 habits로 전달)
    habits = {
        "smoking_status": survey.get("smoking_status"),
        "uv_exposure_10to16": survey.get("uv_exposure_10to16"),
        "drinking_days_per_week": survey.get("drinking_days_per_week"),
        "sleep_hours_weekday": survey.get("sleep_hours_weekday"),
        "stress_score": survey.get("stress_score"),
    }
    
    # 2. 이미지 생성 서비스 호출 (async 함수를 sync 환경에서 실행)
    import asyncio
    try:
        # 이벤트 루프가 없는 경우 새로 생성
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
    
    try:
        result = loop.run_until_complete(
            image_gen_service.request_aging_simulation(
                lifestyle_id=lifestyle_id,
                gender=gender,
                target_years=target_years,
                habits=habits
            )
        )

        print(f"✅ [GenerateAgingImage] 이미지 생성 완료: {result['image_url']}")

        # 3. 결과 반환하여 State 업데이트
        return {
            **state,
            "generated_image_url": result["image_url"],
            "generation_status": result["status"],
            "image_gen_params": result["params"]
        }
    except Exception as e:
        # 이미지 생성 실패는 리포트 본문 생성 실패로 전파하지 않음
        print(f"⚠️ [GenerateAgingImage] 이미지 생성 실패 (리포트는 계속 진행): {e}")
        return {
            **state,
            "generated_image_url": None,
            "generation_status": "failed",
            "image_gen_params": {
                "error": str(e),
                "gender": gender,
                "target_years": target_years,
            },
        }


# ════════════════════════════════════════════════════════════════
#  노드 8: SaveReport
# ════════════════════════════════════════════════════════════════

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
        # State에서 이미지 관련 데이터를 꺼내서 save_report에 전달
        result = save_report(
            user_id, 
            final_report, 
            lifestyle_id=survey.get("lifestyle_id"),
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
        # lifestyle 섹션은 하위 섹션 키들을 확인
        if section == "lifestyle":
            lifestyle_subsection_keys = _get_lifestyle_subsection_keys(survey)
            # lifestyle.* 키들에서 카드 수집
            all_lifestyle_cards = []
            for subsection_key in lifestyle_subsection_keys:
                subsection_cards = section_cards.get(f"{section}.{subsection_key}", [])
                all_lifestyle_cards.extend(subsection_cards)
            
            # lifestyle 섹션 자체에도 카드가 있는지 확인
            main_cards = section_cards.get(section, [])
            if main_cards:
                cards = main_cards
            elif all_lifestyle_cards:
                # 하위 섹션 카드가 있으면 대표 4장 사용
                cards = all_lifestyle_cards[:4]
            else:
                cards = []
            
            if len(cards) == 0:
                print(f"  ⚠️ [{section}] 카드 수 부족 (0개) - 하위 섹션: {lifestyle_subsection_keys}")
                failed_sections.append(section)
                continue
        else:
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


# ════════════════════════════════════════════════════════════════
#  LangGraph 워크플로우
# ════════════════════════════════════════════════════════════════

def create_report_graph():
    """리포트 생성 LangGraph 워크플로우 생성"""
    workflow = StateGraph(ReportState)
    
    workflow.add_node("load_survey", load_survey)
    workflow.add_node("plan_sections", plan_sections)
    workflow.add_node("derive_user_profile", derive_user_profile)
    workflow.add_node("preload_quant_evidence", preload_quant_evidence)
    workflow.add_node("build_queries", build_queries)
    workflow.add_node("retrieve_narrative_evidence", retrieve_narrative_evidence)
    workflow.add_node("extract_claims", extract_claims)
    workflow.add_node("write_section_cards", write_section_cards)
    workflow.add_node("validate_cards", validate_cards)
    workflow.add_node("assemble_report", assemble_report)
    workflow.add_node("generate_aging_image", generate_aging_image_node)
    workflow.add_node("save_report", save_report_node)
    workflow.add_node("export_to_notion", export_to_notion_node)  # 신규 노드 추가
    
    workflow.set_entry_point("load_survey")
    workflow.add_edge("load_survey", "plan_sections")
    workflow.add_edge("plan_sections", "derive_user_profile")  # A. 개인화 복구: user_profile 생성
    workflow.add_edge("derive_user_profile", "preload_quant_evidence")
    workflow.add_edge("preload_quant_evidence", "build_queries")
    workflow.add_edge("build_queries", "retrieve_narrative_evidence")
    workflow.add_edge("retrieve_narrative_evidence", "extract_claims")
    workflow.add_edge("extract_claims", "write_section_cards")  # ExtractClaims는 rule-based로 LLM 호출 없음
    workflow.add_edge("write_section_cards", "validate_cards")
    def _should_retry(state: dict) -> str:
        if state.get("retry_needed") and state.get("retry_sections"):
            rc = state.get("retry_count", {}).get("validate_cards", {})
            for sec in state.get("retry_sections", []):
                if rc.get(sec, 0) <= 1:
                    return "retry"
        return "continue"
    
    workflow.add_conditional_edges(
        "validate_cards",
        _should_retry,
        {"retry": "write_section_cards", "continue": "assemble_report"},
    )
    workflow.add_edge("assemble_report", "generate_aging_image")
    workflow.add_edge("generate_aging_image", "save_report")
    workflow.add_edge("save_report", "export_to_notion")
    workflow.add_edge("export_to_notion", END)

    memory = MemorySaver()
    return workflow.compile(checkpointer=memory)


def generate_report(
    user_id: int,
    lifestyle_id: Optional[int] = None,
    situation_text: Optional[str] = None,
) -> Dict[str, Any]:
    """리포트 생성 메인 함수 (LangGraph 워크플로우)"""
    try:
        initial_state: ReportState = {
            "user_id": user_id,
            "lifestyle_id": lifestyle_id,
            "survey": None,
            "user_profile": None,
            "active_sections": [],
            "available_quant_outcomes": None,
            "quant_evidence_results": {},
            "section_queries": {},
            "narrative_evidence": {},
            "extracted_claims": {},
            "section_cards": {},
            "quality_flags": {},
            "final_report": None,
            "situation_text": situation_text,
        }
        
        app = create_report_graph()
        config = {"configurable": {"thread_id": f"report_user_{user_id}"}}

        final_state = app.invoke(initial_state, config=config)

        final_report = final_state.get("final_report")
        if final_report:
            return {"success": True, "report": final_report}

        return {"success": False, "error": "리포트 생성 실패"}
    except Exception as e:
        print(f"[오류] 리포트 생성 실패: {str(e)}")
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}
