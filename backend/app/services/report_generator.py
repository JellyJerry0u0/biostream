"""
LangGraph 기반 건강 리포트 생성 서비스

이 모듈은 설문조사 데이터를 기반으로 사용자 맞춤형 건강 리포트를 생성합니다.
LangGraph 워크플로우를 사용하여 구조화된 리포트를 생성합니다.
"""

import os
import json
from typing import Dict, Any, List, Optional, TypedDict, Annotated
from langchain_google_genai import ChatGoogleGenerativeAI
from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langgraph.checkpoint.memory import MemorySaver
from langchain_core.messages import HumanMessage, SystemMessage, AIMessage
from sqlalchemy.orm import Session
import time
import google.generativeai as genai

# MCP 클라이언트 import
from .mcp_client import get_user_health_data, validate_section, create_visualization

# Google API Key 설정 (GEMINI_API_KEY도 시도)
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY") or ""
if not GOOGLE_API_KEY:
    print("⚠️ 경고: GOOGLE_API_KEY 또는 GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")
    print("   리포트 생성 기능은 사용할 수 없습니다.")

# LLM 초기화 (API 키가 있을 때만)
# Google Generative AI SDK 직접 초기화 (v1 API 사용)
llm = None
genai_model_name = None
if GOOGLE_API_KEY:
    # google.generativeai 직접 초기화 (v1 API)
    genai.configure(api_key=GOOGLE_API_KEY)
    
    # 사용 가능한 모델 시도 (실제 API에서 사용 가능한 모델)
    models_to_try = [
        "gemini-2.5-flash",  # 최신 플래시 모델 (빠르고 효율적)
        "gemini-2.0-flash",  # 안정적인 플래시 모델
        "gemini-pro-latest",  # 최신 프로 모델
        "gemini-flash-latest",  # 최신 플래시 모델
    ]
    
    for model_name in models_to_try:
        try:
            # 모델이 존재하는지 확인
            model = genai.GenerativeModel(model_name)
            genai_model_name = model_name
            
            # LangChain 래퍼도 초기화 (호환성)
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
    
    if not llm:
        print("❌ 모든 LLM 모델 초기화 실패. GOOGLE_API_KEY를 확인해주세요.")

def invoke_llm_with_retry(messages, max_retries=3, retry_delay=10):
    """재시도 로직이 포함된 LLM 호출 (google.generativeai 직접 사용으로 폴백)"""
    global llm, genai_model_name
    
    if not llm:
        raise ValueError("LLM이 초기화되지 않았습니다. GOOGLE_API_KEY 환경변수를 확인해주세요.")
    
    for attempt in range(max_retries):
        try:
            response = llm.invoke(messages)
            return response
        except Exception as e:
            error_str = str(e)
            
            # 404 에러 (모델을 찾을 수 없음) - google.generativeai 직접 사용으로 폴백
            if "404" in error_str or "NOT_FOUND" in error_str or "not found" in error_str.lower():
                print(f"⚠️ LangChain 래퍼에서 모델을 찾을 수 없습니다. google.generativeai 직접 사용으로 폴백...")
                
                try:
                    # google.generativeai 직접 사용
                    if not genai_model_name:
                        # 사용 가능한 모델 중 첫 번째로 시도
                        genai_model_name = "gemini-2.5-flash"  # 기본값
                    
                    model = genai.GenerativeModel(genai_model_name)
                    
                    # LangChain 메시지를 google.generativeai 형식으로 변환
                    prompt_parts = []
                    for msg in messages:
                        if isinstance(msg, SystemMessage):
                            prompt_parts.append(f"System: {msg.content}")
                        elif isinstance(msg, HumanMessage):
                            prompt_parts.append(msg.content)
                        elif isinstance(msg, AIMessage):
                            prompt_parts.append(f"Assistant: {msg.content}")
                    
                    full_prompt = "\n".join(prompt_parts)
                    
                    # 직접 API 호출
                    response_obj = model.generate_content(
                        full_prompt,
                        generation_config=genai.types.GenerationConfig(temperature=0.7)
                    )
                    
                    # LangChain AIMessage 형식으로 변환
                    from langchain_core.messages import AIMessage
                    return AIMessage(content=response_obj.text)
                    
                except Exception as e2:
                    print(f"⚠️ google.generativeai 직접 호출도 실패: {e2}")
                    raise Exception(f"모든 API 방식 시도 실패: Gemini API 호출에 실패했습니다. ({e2})")
            
            # 429 에러 (할당량 초과) 또는 503 에러 (모델 과부하) - 재시도
            elif "429" in error_str or "RESOURCE_EXHAUSTED" in error_str or "QUOTA" in error_str or \
                 "503" in error_str or "UNAVAILABLE" in error_str or "overloaded" in error_str.lower():
                if attempt < max_retries - 1:
                    # 503 에러는 더 짧은 대기 시간 (모델이 빠르게 복구될 수 있음)
                    if "503" in error_str or "UNAVAILABLE" in error_str:
                        wait_time = min(10 * (attempt + 1), 30)  # 최대 30초
                        print(f"⚠️ 모델 과부하 (503). {wait_time}초 대기 후 재시도... ({attempt + 1}/{max_retries})")
                    else:
                        wait_time = min(retry_delay * (attempt + 1), 15)  # 최대 15초로 제한
                        print(f"⚠️ API 할당량 초과. {wait_time}초 대기 후 재시도... ({attempt + 1}/{max_retries})")
                    time.sleep(wait_time)
                else:
                    error_type = "모델 과부하" if ("503" in error_str or "UNAVAILABLE" in error_str) else "API 할당량 초과"
                    raise Exception(f"{error_type}: Gemini API가 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해주세요.")
            else:
                raise
    
    raise Exception("LLM 호출 실패: 최대 재시도 횟수 초과")


# 상태 정의 (TypedDict 사용)
class ReportState(TypedDict):
    """리포트 생성 상태를 저장하는 TypedDict"""
    lifestyle_data: Dict[str, Any]
    user_id: int
    lifestyle_id: int
    outcomes: List[str]
    target_years: int
    sections: Dict[str, str]  # 섹션 내용
    section_validations: Dict[str, Dict[str, Any]]  # 섹션 검증 결과
    visualizations: Dict[str, Dict[str, Any]]  # 시각자료 데이터
    cards: List[Dict[str, Any]]  # 카드 형태 리포트 데이터
    final_report: Optional[str]
    errors: List[str]
    goal_analysis: Optional[Dict[str, Any]]


# 목표 한글 매핑
OUTCOME_LABELS = {
    "wrinkle": "주름",
    "pigmentation": "색소",
    "hydration": "수분",
    "acne": "여드름",
    "redness": "홍조",
    "general_aging": "전체 노화",
}


def format_lifestyle_data(data: Dict[str, Any]) -> str:
    """생활습관 데이터를 한국어로 포맷팅"""
    formatted = []
    
    # A. 주요 목표
    if data.get("outcomes"):
        outcomes_kr = [OUTCOME_LABELS.get(o, o) for o in data.get("outcomes", [])]
        formatted.append(f"주요 목표: {', '.join(outcomes_kr)}")
    
    # B. 수면 패턴
    if data.get("sleep_hours_weekday") is not None:
        formatted.append(f"평일 수면시간: {data.get('sleep_hours_weekday')}시간")
    if data.get("sleep_hours_weekend") is not None:
        formatted.append(f"주말 수면시간: {data.get('sleep_hours_weekend')}시간")
    if data.get("sleep_quality_score") is not None:
        formatted.append(f"수면의 질: {data.get('sleep_quality_score')}/10점")
    
    # C. 자외선 노출
    uv_mapping = {
        "<30m": "30분 미만",
        "30~60": "30분~1시간",
        "1~2h": "1~2시간",
        ">2h": "2시간 이상"
    }
    if data.get("uv_exposure_10to16"):
        formatted.append(f"야외 노출(10~16시): {uv_mapping.get(data.get('uv_exposure_10to16'), data.get('uv_exposure_10to16'))}")
    
    sunscreen_freq_mapping = {
        "never": "안함",
        "sometimes": "가끔",
        "most_days": "대부분",
        "daily_with_reapply": "매일(재도포 포함)"
    }
    if data.get("sunscreen_frequency"):
        formatted.append(f"선크림 사용 빈도: {sunscreen_freq_mapping.get(data.get('sunscreen_frequency'), data.get('sunscreen_frequency'))}")
    
    # D. 음주 및 흡연
    if data.get("drinking_days_per_week"):
        formatted.append(f"주당 음주일수: {data.get('drinking_days_per_week')}일")
    if data.get("drinking_amount_per_session"):
        formatted.append(f"1회 음주량: {data.get('drinking_amount_per_session')}")
    
    smoking_status_mapping = {
        "never": "안함",
        "former": "과거 흡연",
        "current": "현재 흡연"
    }
    if data.get("smoking_status"):
        formatted.append(f"흡연 상태: {smoking_status_mapping.get(data.get('smoking_status'), data.get('smoking_status'))}")
    
    # E. 스트레스 및 회복
    if data.get("stress_score") is not None:
        formatted.append(f"스트레스 점수(지난 2주): {data.get('stress_score')}/10점")
    if data.get("caffeine_intake"):
        formatted.append(f"카페인 섭취량: {data.get('caffeine_intake')}잔")
    
    # F. 활동 및 대사
    if data.get("aerobic_weekly"):
        formatted.append(f"유산소 운동(주당): {data.get('aerobic_weekly')}회")
    if data.get("resistance_weekly"):
        formatted.append(f"근력 운동(주당): {data.get('resistance_weekly')}회")
    if data.get("height"):
        formatted.append(f"키: {data.get('height')}cm")
    if data.get("weight"):
        formatted.append(f"몸무게: {data.get('weight')}kg")
    
    # 피부 상태
    skin_type_mapping = {
        "dry": "건성",
        "oily": "지성",
        "combination": "복합성",
        "sensitive": "민감성"
    }
    if data.get("skin_type"):
        formatted.append(f"피부 타입: {skin_type_mapping.get(data.get('skin_type'), data.get('skin_type'))}")
    if data.get("skin_concerns"):
        concerns_kr = [OUTCOME_LABELS.get(c, c) for c in data.get("skin_concerns", [])]
        formatted.append(f"주요 피부 고민: {', '.join(concerns_kr)}")
    if data.get("skin_satisfaction") is not None:
        formatted.append(f"피부 만족도: {data.get('skin_satisfaction')}/10점")
    
    # 목표 연도
    if data.get("target_years"):
        formatted.append(f"목표 미래 나이: +{data.get('target_years')}년")
    
    return "\n".join(formatted)


# 노드 1: 사용자 데이터 수집 및 목표 분석 (MCP 사용)
def collect_data_and_analyze_goals(state: ReportState) -> ReportState:
    """사용자 데이터 수집 및 주요 목표 분석
    
    API에서 이미 조회한 lifestyle_data를 사용하고,
    MCP는 추가 컨텍스트(프로필 정보 등)만 조회합니다.
    """
    try:
        user_id = state["user_id"]
        lifestyle_data = state["lifestyle_data"]  # API에서 이미 조회한 데이터 사용
        
        # MCP를 통해 추가 컨텍스트만 조회 (프로필 정보 등)
        print(f"[리포트 생성] MCP를 통해 추가 컨텍스트 조회 시작 - user_id: {user_id}")
        user_health_data = get_user_health_data(user_id)
        
        # MCP 조회 실패해도 계속 진행 (기본 데이터는 이미 있음)
        mcp_profile = {}
        if "error" not in user_health_data:
            mcp_profile = user_health_data.get("profile", {})
            print(f"[리포트 생성] MCP 프로필 정보 조회 완료: {mcp_profile}")
        else:
            print(f"[리포트 생성] MCP 조회 실패 (계속 진행): {user_health_data.get('error')}")
        
        # API에서 조회한 lifestyle_data를 그대로 사용 (MCP 데이터로 덮어쓰지 않음)
        outcomes = lifestyle_data.get("outcomes", [])
        
        # outcomes가 None이거나 빈 리스트인 경우 확인
        if not outcomes or (isinstance(outcomes, list) and len(outcomes) == 0):
            print(f"⚠️ [리포트 생성] outcomes가 비어있습니다. lifestyle_data: {lifestyle_data.get('outcomes')}")
            outcomes = []
        
        # 목표 분석
        goals_text = ", ".join([OUTCOME_LABELS.get(o, o) for o in outcomes]) if outcomes else "없음"
        
        goal_analysis = {
            "primary_goals": outcomes,
            "goals_text": goals_text,
            "target_years": state["target_years"],
            "user_profile": mcp_profile  # 유저 프로필 정보 추가
        }
        
        # 상태 업데이트
        updated_state = state.copy()
        updated_state["lifestyle_data"] = lifestyle_data
        updated_state["outcomes"] = outcomes  # outcomes를 state에 명시적으로 설정
        updated_state["goal_analysis"] = goal_analysis
        updated_state["section_validations"] = {}
        updated_state["visualizations"] = {}
        updated_state["cards"] = []
        
        print(f"[리포트 생성] MCP 데이터 수집 완료 - 목표: {goals_text}")
        return updated_state
    except Exception as e:
        error_msg = f"데이터 수집 중 오류: {str(e)}"
        updated_state = state.copy()
        updated_state["errors"] = state.get("errors", []) + [error_msg]
        print(f"[오류] 데이터 수집 실패: {str(e)}")
        return updated_state


# 노드 2: 주요 목표 섹션 생성 (중점 섹션)
def generate_goals_section(state: ReportState) -> ReportState:
    """주요 목표에 대한 중점 섹션 생성"""
    print(f"[리포트 생성] 주요 목표 섹션 생성 시작 - outcomes: {state.get('outcomes', [])}")
    try:
        lifestyle_data = state["lifestyle_data"]
        outcomes = state["outcomes"]
        target_years = state["target_years"]
        
        if not outcomes:
            print("[리포트 생성] 목표가 설정되지 않음 - LLM으로 기본 내용 생성")
            # outcomes가 없어도 LLM을 호출해서 일반적인 건강 관리 가이드 생성
            goals_text = "전반적인 건강 증진"
        else:
            goals_text = ", ".join([OUTCOME_LABELS.get(o, o) for o in outcomes])
        
        print(f"[리포트 생성] 목표 텍스트: {goals_text}, 목표 연도: +{target_years}년")
        formatted_data = format_lifestyle_data(lifestyle_data)
        print(f"[리포트 생성] 포맷된 데이터 길이: {len(formatted_data)}자")
        
        prompt = f"""당신은 건강 및 피부 관리 전문가입니다. 다음 정보를 바탕으로 사용자의 주요 목표({goals_text})에 중점을 둔 상세한 건강 리포트 섹션을 작성해주세요.

사용자 정보:
{formatted_data}

목표 미래 연도: +{target_years}년

다음 형식으로 작성해주세요:
1. 현재 상태 분석: 사용자의 주요 목표와 관련된 현재 생활습관을 분석
2. 예상 결과: 현재 패턴을 유지할 경우 {target_years}년 후 예상되는 상태
3. 개선 방안: 목표 달성을 위한 구체적이고 실천 가능한 권장사항 (각 목표별로 상세히)
4. 우선순위: 가장 중요한 개선 사항 3가지

한국어로 자연스럽고 전문적으로 작성해주세요. 각 목표({goals_text})를 중심으로 구체적이고 실천 가능한 조언을 제공해주세요.
"""
        
        messages = [
            SystemMessage(content="당신은 건강 및 피부 관리 전문가입니다. 사용자의 목표를 중심으로 구체적이고 실용적인 조언을 제공합니다."),
            HumanMessage(content=prompt)
        ]
        
        # LLM 호출 및 응답 검증 (최대 2번 재시도)
        print(f"[리포트 생성] LLM 호출 시작 - 프롬프트 길이: {len(prompt)}자")
        goals_section = None
        for retry_count in range(2):
            try:
                print(f"[리포트 생성] LLM 호출 시도 {retry_count + 1}/2")
                response = invoke_llm_with_retry(messages, max_retries=3)
                goals_section = response.content if hasattr(response, 'content') else str(response)
                print(f"[리포트 생성] LLM 응답 받음 - 길이: {len(goals_section) if goals_section else 0}자")
                
                # 응답이 비어있거나 너무 짧은 경우 재시도
                if not goals_section or len(goals_section.strip()) < 50:
                    if retry_count < 1:
                        print(f"⚠️ 목표 섹션 응답이 너무 짧음 ({len(goals_section) if goals_section else 0}자). 재시도...")
                        time.sleep(2)
                        continue
                    else:
                        print(f"❌ 목표 섹션 응답이 계속 짧음 - 최종 길이: {len(goals_section) if goals_section else 0}자")
                        raise Exception(f"LLM 응답이 비어있거나 너무 짧습니다. (길이: {len(goals_section) if goals_section else 0}자)")
                print(f"✅ 목표 섹션 응답 검증 통과 - 길이: {len(goals_section)}자")
                break
            except Exception as e:
                print(f"⚠️ 목표 섹션 생성 실패, 재시도 중... ({retry_count + 1}/2): {str(e)}")
                if retry_count < 1:
                    time.sleep(2)
                    continue
                else:
                    print(f"❌ 목표 섹션 생성 최종 실패: {str(e)}")
                    raise
        
        if not goals_section:
            raise Exception("목표 섹션 생성에 실패했습니다.")
        
        # MCP를 통한 섹션 검증
        validation_result = validate_section(goals_section, "goals")
        
        # 시각자료 생성
        visualization_result = create_visualization("goals", goals_section, lifestyle_data)
        
        updated_state = state.copy()
        updated_state["sections"] = state["sections"].copy()
        updated_state["sections"]["goals"] = goals_section
        updated_state["section_validations"] = state.get("section_validations", {}).copy()
        updated_state["section_validations"]["goals"] = validation_result
        updated_state["visualizations"] = state.get("visualizations", {}).copy()
        if visualization_result.get("success"):
            updated_state["visualizations"]["goals"] = visualization_result
        
        print(f"[리포트 생성] 주요 목표 섹션 생성 완료 - 검증: {validation_result.get('is_valid', False)}")
        return updated_state
        
    except Exception as e:
        error_msg = f"목표 섹션 생성 중 오류: {str(e)}"
        import traceback
        traceback.print_exc()
        
        # goals 섹션은 필수이므로 기본 내용이라도 생성
        outcomes = state.get("outcomes", [])
        goals_text = ", ".join([OUTCOME_LABELS.get(o, o) for o in outcomes]) if outcomes else "전반적 건강"
        target_years = state.get("target_years", 30)
        
        fallback_content = f"""## 주요 목표 분석 및 개선 방안

현재 목표: {goals_text}
예측 기간: {target_years}년 후

### 현재 상태
사용자의 주요 목표와 관련된 생활습관을 분석한 결과, 개선이 필요한 영역이 확인되었습니다.

### 예상 결과
현재 생활 패턴을 유지할 경우, {target_years}년 후 목표 달성에 어려움이 예상됩니다.

### 개선 방안
1. 규칙적인 생활 패턴 유지
2. 건강한 식습관 및 수면 습관 개선
3. 꾸준한 피부 관리 및 보호

**참고**: AI 생성 중 오류가 발생하여 기본 가이드를 제공합니다. 다시 시도해주시면 더 상세한 분석을 제공할 수 있습니다.

오류 상세: {str(e)}
"""
        
        updated_state = state.copy()
        updated_state["errors"] = state.get("errors", []) + [error_msg]
        updated_state["sections"] = state.get("sections", {}).copy()
        updated_state["sections"]["goals"] = fallback_content
        print(f"[오류] {error_msg}")
        print(f"[리포트 생성] 목표 섹션 기본 내용 생성 (오류 발생으로 인한 폴백)")
        return updated_state


# 노드 3: 수면 및 리듬 섹션 생성
def generate_sleep_section(state: ReportState) -> ReportState:
    """수면 패턴 섹션 생성"""
    try:
        lifestyle_data = state["lifestyle_data"]
        
        sleep_data = {
            "weekday": lifestyle_data.get("sleep_hours_weekday"),
            "weekend": lifestyle_data.get("sleep_hours_weekend"),
            "quality": lifestyle_data.get("sleep_quality_score"),
        }
        
        print(f"[리포트 생성] 수면 섹션 생성 시작 - weekday: {sleep_data['weekday']}, weekend: {sleep_data['weekend']}, quality: {sleep_data['quality']}")
        
        if all(v is None for v in sleep_data.values()):
            print("⚠️ [리포트 생성] 수면 데이터가 모두 None입니다.")
            updated_state = state.copy()
            updated_state["sections"] = state["sections"].copy()
            updated_state["sections"]["sleep"] = "수면 정보가 제공되지 않았습니다."
            return updated_state
        
        formatted_data = format_lifestyle_data(lifestyle_data)
        
        prompt = f"""다음 사용자의 수면 패턴 정보를 바탕으로 건강 리포트의 수면 및 리듬 섹션을 작성해주세요.

사용자 정보:
{formatted_data}

수면 패턴:
- 평일 수면시간: {sleep_data['weekday']}시간
- 주말 수면시간: {sleep_data['weekend']}시간
- 수면의 질: {sleep_data['quality']}/10점

다음 내용을 포함해주세요:
1. 현재 수면 패턴 평가
2. 수면 패턴이 피부 및 전반적 건강에 미치는 영향
3. 개선을 위한 구체적 권장사항

한국어로 전문적이고 실용적으로 작성해주세요.
"""
        
        messages = [
            SystemMessage(content="당신은 수면 및 건강 전문가입니다."),
            HumanMessage(content=prompt)
        ]
        
        # LLM 호출 및 응답 검증 (최대 2번 재시도)
        sleep_section = None
        for retry_count in range(2):
            try:
                response = invoke_llm_with_retry(messages, max_retries=3)
                sleep_section = response.content if hasattr(response, 'content') else str(response)
                
                # 응답이 비어있거나 너무 짧은 경우 재시도
                if not sleep_section or len(sleep_section.strip()) < 50:
                    if retry_count < 1:
                        print(f"⚠️ 수면 섹션 응답이 너무 짧음 ({len(sleep_section) if sleep_section else 0}자). 재시도...")
                        time.sleep(2)
                        continue
                    else:
                        raise Exception("LLM 응답이 비어있거나 너무 짧습니다.")
                break
            except Exception as e:
                if retry_count < 1:
                    print(f"⚠️ 수면 섹션 생성 실패, 재시도 중... ({retry_count + 1}/2): {str(e)}")
                    time.sleep(2)
                    continue
                else:
                    raise
        
        if not sleep_section:
            raise Exception("수면 섹션 생성에 실패했습니다.")
        
        # MCP를 통한 섹션 검증
        validation_result = validate_section(sleep_section, "sleep")
        
        # 시각자료 생성
        visualization_result = create_visualization("sleep", sleep_section, lifestyle_data)
        
        updated_state = state.copy()
        updated_state["sections"] = state["sections"].copy()
        updated_state["sections"]["sleep"] = sleep_section
        updated_state["section_validations"] = state.get("section_validations", {}).copy()
        updated_state["section_validations"]["sleep"] = validation_result
        updated_state["visualizations"] = state.get("visualizations", {}).copy()
        if visualization_result.get("success"):
            updated_state["visualizations"]["sleep"] = visualization_result
        
        print(f"[리포트 생성] 수면 섹션 생성 완료 - 검증: {validation_result.get('is_valid', False)}")
        return updated_state
        
    except Exception as e:
        error_msg = f"수면 섹션 생성 중 오류: {str(e)}"
        import traceback
        traceback.print_exc()
        
        # 오류 발생 시에도 기본 내용 생성
        default_sleep_content = f"""### 수면 및 리듬 분석

**현재 수면 패턴:**
- 평일 수면시간: {lifestyle_data.get('sleep_hours_weekday', 'N/A')}시간
- 주말 수면시간: {lifestyle_data.get('sleep_hours_weekend', 'N/A')}시간
- 수면의 질: {lifestyle_data.get('sleep_quality_score', 'N/A')}/10점

**수면 패턴 평가:**
현재 수면 패턴이 건강과 피부에 미치는 영향을 분석합니다. 충분한 수면은 피부 세포 재생, 호르몬 조절, 면역력 강화에 필수적입니다.

**개선 권장사항:**
1. **규칙적인 수면 시간:** 매일 같은 시간에 잠자리에 들고 일어나는 것이 중요합니다.
2. **적정 수면 시간:** 성인의 경우 7-9시간의 수면이 권장됩니다.
3. **수면 환경 개선:** 어둡고 조용한 환경, 적절한 온도 유지가 중요합니다.
4. **낮잠 피하기:** 저녁 수면에 영향을 주지 않도록 낮잠을 피하거나 짧게 제한하세요.
"""
        
        updated_state = state.copy()
        updated_state["errors"] = state.get("errors", []) + [error_msg]
        updated_state["sections"] = state.get("sections", {}).copy()
        updated_state["sections"]["sleep"] = default_sleep_content
        
        # 검증 및 시각화도 추가
        validation_result = validate_section(default_sleep_content, "sleep")
        visualization_result = create_visualization("sleep", default_sleep_content, lifestyle_data)
        
        updated_state["section_validations"] = state.get("section_validations", {}).copy()
        updated_state["section_validations"]["sleep"] = validation_result
        updated_state["visualizations"] = state.get("visualizations", {}).copy()
        if visualization_result.get("success"):
            updated_state["visualizations"]["sleep"] = visualization_result
        
        print(f"[오류] {error_msg} - 기본 내용으로 대체")
        return updated_state


# 노드 4: 자외선 및 노화 섹션 생성
def generate_uv_section(state: ReportState) -> ReportState:
    """자외선 노출 및 노화 섹션 생성"""
    try:
        lifestyle_data = state["lifestyle_data"]
        formatted_data = format_lifestyle_data(lifestyle_data)
        
        prompt = f"""다음 사용자의 자외선 노출 정보를 바탕으로 건강 리포트의 자외선 및 노화 섹션을 작성해주세요.

사용자 정보:
{formatted_data}

다음 내용을 포함해주세요:
1. 현재 자외선 노출 패턴 평가
2. 자외선이 피부 노화 및 건강에 미치는 영향
3. 개선을 위한 구체적 권장사항 (선크림 사용법, 외출 시간 조절 등)

한국어로 전문적이고 실용적으로 작성해주세요.
"""
        
        messages = [
            SystemMessage(content="당신은 피부 건강 및 자외선 노출 전문가입니다."),
            HumanMessage(content=prompt)
        ]
        
        # LLM 호출 및 응답 검증 (최대 2번 재시도)
        uv_section = None
        for retry_count in range(2):
            try:
                response = invoke_llm_with_retry(messages, max_retries=2)  # 재시도 횟수 감소
                uv_section = response.content if hasattr(response, 'content') else str(response)
                
                if not uv_section or len(uv_section.strip()) < 50:
                    if retry_count < 1:
                        print(f"⚠️ 자외선 섹션 응답이 너무 짧음 ({len(uv_section) if uv_section else 0}자). 재시도...")
                        time.sleep(1)  # 짧은 대기
                        continue
                    else:
                        raise Exception("LLM 응답이 비어있거나 너무 짧습니다.")
                break
            except Exception as e:
                if retry_count < 1:
                    print(f"⚠️ 자외선 섹션 생성 실패, 재시도 중... ({retry_count + 1}/2): {str(e)}")
                    time.sleep(1)  # 짧은 대기
                    continue
                else:
                    raise
        
        if not uv_section:
            raise Exception("자외선 섹션 생성에 실패했습니다.")
        
        # MCP를 통한 섹션 검증
        validation_result = validate_section(uv_section, "uv")
        
        # 시각자료 생성
        visualization_result = create_visualization("uv", uv_section, lifestyle_data)
        
        updated_state = state.copy()
        updated_state["sections"] = state["sections"].copy()
        updated_state["sections"]["uv"] = uv_section
        updated_state["section_validations"] = state.get("section_validations", {}).copy()
        updated_state["section_validations"]["uv"] = validation_result
        updated_state["visualizations"] = state.get("visualizations", {}).copy()
        if visualization_result.get("success"):
            updated_state["visualizations"]["uv"] = visualization_result
        
        print(f"[리포트 생성] 자외선 섹션 생성 완료 - 검증: {validation_result.get('is_valid', False)}")
        return updated_state
        
    except Exception as e:
        error_msg = f"자외선 섹션 생성 중 오류: {str(e)}"
        import traceback
        traceback.print_exc()
        
        # 오류 발생 시에도 기본 내용 생성
        default_uv_content = f"""### 자외선 노출 및 노화 분석

**현재 자외선 노출 패턴:**
- 야외 노출 시간(10~16시): {lifestyle_data.get('uv_exposure_10to16', 'N/A')}
- 선크림 사용 빈도: {lifestyle_data.get('sunscreen_frequency', 'N/A')}
- 선크림 재도포: {lifestyle_data.get('sunscreen_reapply', 'N/A')}
- 야외 스포츠: {lifestyle_data.get('outdoor_sports_uv', 'N/A')}

**자외선 노출 평가:**
자외선은 피부 노화의 주요 원인 중 하나입니다. UVA는 주름과 탄력 저하를, UVB는 색소 침착과 화상의 원인입니다. 적절한 자외선 차단이 피부 건강과 노화 예방에 필수적입니다.

**개선 권장사항:**
1. **선크림 일상 사용:** SPF 30 이상, PA+++ 이상의 선크림을 매일 사용하세요.
2. **재도포:** 외출 시 2-3시간마다 선크림을 재도포하는 것이 중요합니다.
3. **자외선 강한 시간대 피하기:** 오전 10시부터 오후 4시까지는 최대한 실내에 있거나 그늘을 이용하세요.
4. **피부 보호 장비:** 모자, 선글라스, 긴팔 옷 등으로 피부를 보호하세요.

**참고**: AI 생성 중 오류가 발생하여 기본 가이드를 제공합니다. 다시 시도해주시면 더 상세한 분석을 제공할 수 있습니다.
"""
        
        updated_state = state.copy()
        updated_state["errors"] = state.get("errors", []) + [error_msg]
        updated_state["sections"] = state.get("sections", {}).copy()
        updated_state["sections"]["uv"] = default_uv_content
        
        # 검증 및 시각화도 추가
        validation_result = validate_section(default_uv_content, "uv")
        visualization_result = create_visualization("uv", default_uv_content, lifestyle_data)
        
        updated_state["section_validations"] = state.get("section_validations", {}).copy()
        updated_state["section_validations"]["uv"] = validation_result
        updated_state["visualizations"] = state.get("visualizations", {}).copy()
        if visualization_result.get("success"):
            updated_state["visualizations"]["uv"] = visualization_result
        
        print(f"[오류] {error_msg} - 기본 내용으로 대체")
        return updated_state


# 노드 5: 생활습관 섹션 생성 (음주, 흡연, 스트레스)
def generate_lifestyle_section(state: ReportState) -> ReportState:
    """생활습관 섹션 생성 (음주, 흡연, 스트레스)"""
    try:
        lifestyle_data = state["lifestyle_data"]
        formatted_data = format_lifestyle_data(lifestyle_data)
        
        prompt = f"""다음 사용자의 생활습관 정보(음주, 흡연, 스트레스, 카페인)를 바탕으로 건강 리포트의 생활습관 섹션을 작성해주세요.

사용자 정보:
{formatted_data}

다음 내용을 포함해주세요:
1. 현재 생활습관 평가
2. 각 요소가 피부 및 전반적 건강에 미치는 영향
3. 개선을 위한 구체적 권장사항

한국어로 전문적이고 실용적으로 작성해주세요.
"""
        
        messages = [
            SystemMessage(content="당신은 생활습관 및 건강 전문가입니다."),
            HumanMessage(content=prompt)
        ]
        
        # LLM 호출 및 응답 검증 (최대 2번 재시도)
        lifestyle_section = None
        for retry_count in range(2):
            try:
                response = invoke_llm_with_retry(messages, max_retries=3)
                lifestyle_section = response.content if hasattr(response, 'content') else str(response)
                
                if not lifestyle_section or len(lifestyle_section.strip()) < 50:
                    if retry_count < 1:
                        print(f"⚠️ 생활습관 섹션 응답이 너무 짧음 ({len(lifestyle_section) if lifestyle_section else 0}자). 재시도...")
                        time.sleep(2)
                        continue
                    else:
                        raise Exception("LLM 응답이 비어있거나 너무 짧습니다.")
                break
            except Exception as e:
                if retry_count < 1:
                    print(f"⚠️ 생활습관 섹션 생성 실패, 재시도 중... ({retry_count + 1}/2): {str(e)}")
                    time.sleep(2)
                    continue
                else:
                    raise
        
        if not lifestyle_section:
            raise Exception("생활습관 섹션 생성에 실패했습니다.")
        
        # MCP를 통한 섹션 검증
        validation_result = validate_section(lifestyle_section, "lifestyle")
        
        # 시각자료 생성
        visualization_result = create_visualization("lifestyle", lifestyle_section, lifestyle_data)
        
        updated_state = state.copy()
        updated_state["sections"] = state["sections"].copy()
        updated_state["sections"]["lifestyle"] = lifestyle_section
        updated_state["section_validations"] = state.get("section_validations", {}).copy()
        updated_state["section_validations"]["lifestyle"] = validation_result
        updated_state["visualizations"] = state.get("visualizations", {}).copy()
        if visualization_result.get("success"):
            updated_state["visualizations"]["lifestyle"] = visualization_result
        
        print(f"[리포트 생성] 생활습관 섹션 생성 완료 - 검증: {validation_result.get('is_valid', False)}")
        return updated_state
        
    except Exception as e:
        error_msg = f"생활습관 섹션 생성 중 오류: {str(e)}"
        import traceback
        traceback.print_exc()
        
        # 오류 발생 시에도 기본 내용 생성
        default_lifestyle_content = f"""### 생활습관 분석

**현재 생활습관:**
- 흡연 상태: {lifestyle_data.get('smoking_status', 'N/A')}
- 주당 음주 일수: {lifestyle_data.get('drinking_days_per_week', 'N/A')}
- 1회 음주량: {lifestyle_data.get('drinking_amount_per_session', 'N/A')}
- 스트레스 점수: {lifestyle_data.get('stress_score', 'N/A')}/10
- 카페인 섭취량: {lifestyle_data.get('caffeine_intake', 'N/A')}
- 카페인 섭취 시간대: {lifestyle_data.get('caffeine_timing', 'N/A')}

**생활습관 평가:**
생활습관은 피부 건강과 전반적인 웰빙에 직접적인 영향을 미칩니다. 흡연, 과도한 음주, 높은 스트레스, 불규칙한 카페인 섭취는 피부 노화를 가속화하고 건강을 해칠 수 있습니다.

**개선 권장사항:**
1. **흡연 금지:** 흡연은 피부 탄력을 떨어뜨리고 주름을 증가시킵니다. 금연을 권장합니다.
2. **절주:** 과도한 음주는 탈수를 유발하고 피부 염증을 증가시킬 수 있습니다. 주당 1-2회, 소량 섭취를 권장합니다.
3. **스트레스 관리:** 명상, 운동, 취미 활동 등으로 스트레스를 관리하세요.
4. **카페인 섭취 조절:** 오후 2시 이후 카페인 섭취를 피하고, 하루 2-3잔 이하로 제한하세요.

**참고**: AI 생성 중 오류가 발생하여 기본 가이드를 제공합니다. 다시 시도해주시면 더 상세한 분석을 제공할 수 있습니다.
"""
        
        updated_state = state.copy()
        updated_state["errors"] = state.get("errors", []) + [error_msg]
        updated_state["sections"] = state.get("sections", {}).copy()
        updated_state["sections"]["lifestyle"] = default_lifestyle_content
        
        # 검증 및 시각화도 추가
        validation_result = validate_section(default_lifestyle_content, "lifestyle")
        visualization_result = create_visualization("lifestyle", default_lifestyle_content, lifestyle_data)
        
        updated_state["section_validations"] = state.get("section_validations", {}).copy()
        updated_state["section_validations"]["lifestyle"] = validation_result
        updated_state["visualizations"] = state.get("visualizations", {}).copy()
        if visualization_result.get("success"):
            updated_state["visualizations"]["lifestyle"] = visualization_result
        
        print(f"[오류] {error_msg} - 기본 내용으로 대체")
        return updated_state


# 노드 6: 활동 및 대사 섹션 생성
def generate_activity_section(state: ReportState) -> ReportState:
    """활동 및 대사 섹션 생성"""
    try:
        lifestyle_data = state["lifestyle_data"]
        formatted_data = format_lifestyle_data(lifestyle_data)
        
        prompt = f"""다음 사용자의 운동 및 대사 정보를 바탕으로 건강 리포트의 활동 및 대사 섹션을 작성해주세요.

사용자 정보:
{formatted_data}

다음 내용을 포함해주세요:
1. 현재 운동 패턴 평가
2. 운동이 피부 및 전반적 건강에 미치는 영향
3. 개선을 위한 구체적 권장사항 (운동 유형, 빈도, 강도)

한국어로 전문적이고 실용적으로 작성해주세요.
"""
        
        messages = [
            SystemMessage(content="당신은 운동 및 대사 전문가입니다."),
            HumanMessage(content=prompt)
        ]
        
        # LLM 호출 및 응답 검증 (최대 2번 재시도)
        activity_section = None
        for retry_count in range(2):
            try:
                response = invoke_llm_with_retry(messages, max_retries=3)
                activity_section = response.content if hasattr(response, 'content') else str(response)
                
                if not activity_section or len(activity_section.strip()) < 50:
                    if retry_count < 1:
                        print(f"⚠️ 활동 섹션 응답이 너무 짧음 ({len(activity_section) if activity_section else 0}자). 재시도...")
                        time.sleep(2)
                        continue
                    else:
                        raise Exception("LLM 응답이 비어있거나 너무 짧습니다.")
                break
            except Exception as e:
                if retry_count < 1:
                    print(f"⚠️ 활동 섹션 생성 실패, 재시도 중... ({retry_count + 1}/2): {str(e)}")
                    time.sleep(2)
                    continue
                else:
                    raise
        
        if not activity_section:
            raise Exception("활동 섹션 생성에 실패했습니다.")
        
        # MCP를 통한 섹션 검증
        validation_result = validate_section(activity_section, "activity")
        
        # 시각자료 생성
        visualization_result = create_visualization("activity", activity_section, lifestyle_data)
        
        updated_state = state.copy()
        updated_state["sections"] = state["sections"].copy()
        updated_state["sections"]["activity"] = activity_section
        updated_state["section_validations"] = state.get("section_validations", {}).copy()
        updated_state["section_validations"]["activity"] = validation_result
        updated_state["visualizations"] = state.get("visualizations", {}).copy()
        if visualization_result.get("success"):
            updated_state["visualizations"]["activity"] = visualization_result
        
        print(f"[리포트 생성] 활동 섹션 생성 완료 - 검증: {validation_result.get('is_valid', False)}")
        return updated_state
        
    except Exception as e:
        error_msg = f"활동 섹션 생성 중 오류: {str(e)}"
        updated_state = state.copy()
        updated_state["errors"] = state.get("errors", []) + [error_msg]
        updated_state["sections"] = state.get("sections", {}).copy()
        updated_state["sections"]["activity"] = "활동 섹션 생성 중 오류가 발생했습니다."
        print(f"[오류] {error_msg}")
        return updated_state


# 노드 7: 최종 리포트 통합 및 카드 생성
def integrate_report(state: ReportState) -> ReportState:
    """모든 섹션을 통합하여 최종 리포트 및 카드 형태 데이터 생성"""
    try:
        sections = state["sections"]
        outcomes = state["outcomes"]
        target_years = state["target_years"]
        visualizations = state.get("visualizations", {})
        section_validations = state.get("section_validations", {})
        
        goals_text = ", ".join([OUTCOME_LABELS.get(o, o) for o in outcomes]) if outcomes else "전반적 건강"
        
        # 리포트 구조 생성 (텍스트 리포트)
        report_parts = []
        report_parts.append("=" * 60)
        report_parts.append(f"건강 리포트 - 목표: {goals_text}")
        report_parts.append(f"예측 기간: +{target_years}년")
        report_parts.append("=" * 60)
        report_parts.append("")
        
        # 카드 형태 데이터 생성
        cards = []
        
        # 카드 정의 (순서, 아이콘, 제목)
        card_configs = [
            {"key": "goals", "icon": "📌", "title": "주요 목표 분석 및 개선 방안", "order": 0},
            {"key": "sleep", "icon": "🌙", "title": "수면 및 리듬", "order": 1},
            {"key": "uv", "icon": "☀️", "title": "자외선 및 노화 관리", "order": 2},
            {"key": "lifestyle", "icon": "🍷", "title": "생활습관 관리", "order": 3},
            {"key": "activity", "icon": "💪", "title": "활동 및 대사", "order": 4},
        ]
        
        for config in card_configs:
            key = config["key"]
            section_content = sections.get(key, "")
            
            # 빈 섹션이거나 오류 메시지만 있는 경우 제외 (최소 길이를 50자로 상향)
            if not section_content or len(section_content.strip()) < 50:
                print(f"[리포트 생성] 섹션 '{key}' 건너뜀: 내용이 비어있거나 너무 짧음 ({len(section_content) if section_content else 0}자)")
                continue
            
            # 오류 메시지만 있는 경우 제외
            error_indicators = [
                "오류가 발생했습니다",
                "생성 중 오류",
                "error occurred",
                "failed to generate",
                "오류"
            ]
            if any(indicator in section_content for indicator in error_indicators) and len(section_content.strip()) < 50:
                print(f"[리포트 생성] 섹션 '{key}' 건너뜀: 오류 메시지만 포함됨")
                continue
            
            card = {
                "id": key,
                "order": config["order"],
                "icon": config["icon"],
                "title": config["title"],
                "content": section_content,
                "has_visualization": False,
                "visualization": None,
                "validation": section_validations.get(key, {}),
            }
            
            # 시각자료 추가
            if key in visualizations and visualizations[key].get("success"):
                card["has_visualization"] = True
                card["visualization"] = {
                    "chart_type": visualizations[key].get("chart_type"),
                    "image_base64": visualizations[key].get("image_base64"),
                    "description": visualizations[key].get("description", ""),
                }
            
            cards.append(card)
            
            # 텍스트 리포트에도 추가
            report_parts.append(f"{config['icon']} {config['title']}")
            report_parts.append("-" * 60)
            report_parts.append(sections[key])
            report_parts.append("")
        
        # 카드 순서 정렬
        cards.sort(key=lambda x: x["order"])
        
        # 마무리
        report_parts.append("=" * 60)
        report_parts.append("리포트 완료")
        report_parts.append("=" * 60)
        
        final_report = "\n".join(report_parts)
        updated_state = state.copy()
        updated_state["final_report"] = final_report
        updated_state["cards"] = cards
        
        print(f"[리포트 생성] 최종 리포트 통합 완료 - 카드 수: {len(cards)}")
        return updated_state
        
    except Exception as e:
        error_msg = f"리포트 통합 중 오류: {str(e)}"
        updated_state = state.copy()
        updated_state["errors"] = state.get("errors", []) + [error_msg]
        updated_state["final_report"] = "리포트 생성 중 오류가 발생했습니다."
        updated_state["cards"] = []
        print(f"[오류] {error_msg}")
        return updated_state


# LangGraph 워크플로우 구성
def create_report_graph():
    """리포트 생성 LangGraph 워크플로우 생성"""
    workflow = StateGraph(ReportState)
    
    # 노드 추가
    workflow.add_node("collect_data", collect_data_and_analyze_goals)
    workflow.add_node("goals_section", generate_goals_section)
    workflow.add_node("sleep_section", generate_sleep_section)
    workflow.add_node("uv_section", generate_uv_section)
    workflow.add_node("lifestyle_section", generate_lifestyle_section)
    workflow.add_node("activity_section", generate_activity_section)
    workflow.add_node("integrate", integrate_report)
    
    # 엣지 설정
    workflow.set_entry_point("collect_data")
    workflow.add_edge("collect_data", "goals_section")
    workflow.add_edge("goals_section", "sleep_section")
    workflow.add_edge("sleep_section", "uv_section")
    workflow.add_edge("uv_section", "lifestyle_section")
    workflow.add_edge("lifestyle_section", "activity_section")
    workflow.add_edge("activity_section", "integrate")
    workflow.add_edge("integrate", END)
    
    # 메모리 체크포인터 추가
    memory = MemorySaver()
    app = workflow.compile(checkpointer=memory)
    
    return app


# 리포트 생성 함수
def generate_health_report(
    lifestyle_data: Dict[str, Any],
    user_id: int,
    lifestyle_id: int
) -> Dict[str, Any]:
    """
    건강 리포트 생성 메인 함수
    
    Args:
        lifestyle_data: 설문조사 데이터
        user_id: 사용자 ID
        lifestyle_id: Lifestyle 레코드 ID
    
    Returns:
        리포트 데이터 (섹션별 및 통합 리포트 포함)
    """
    try:
        # 초기 상태 생성 (TypedDict 형식)
        initial_state: ReportState = {
            "lifestyle_data": lifestyle_data,
            "user_id": user_id,
            "lifestyle_id": lifestyle_id,
            "outcomes": lifestyle_data.get("outcomes", []),
            "target_years": lifestyle_data.get("target_years", 30),
            "sections": {},
            "section_validations": {},
            "visualizations": {},
            "cards": [],
            "final_report": None,
            "errors": [],
            "goal_analysis": None
        }
        
        # 워크플로우 실행
        app = create_report_graph()
        
        config = {"configurable": {"thread_id": f"user_{user_id}_lifestyle_{lifestyle_id}"}}
        
        final_state = None
        for state in app.stream(initial_state, config):
            final_state = state
        
        if final_state:
            # 마지막 상태에서 결과 추출
            # stream()은 노드 이름을 키로 하는 딕셔너리를 반환
            last_node_key = list(final_state.keys())[-1] if final_state else None
            if last_node_key:
                result_state = final_state[last_node_key]
            else:
                result_state = initial_state
            
            return {
                "success": True,
                "sections": result_state.get("sections", {}),
                "section_validations": result_state.get("section_validations", {}),
                "visualizations": result_state.get("visualizations", {}),
                "cards": result_state.get("cards", []),  # 카드 형태 데이터
                "final_report": result_state.get("final_report", ""),
                "errors": result_state.get("errors", []),
                "goal_analysis": result_state.get("goal_analysis", {})
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
