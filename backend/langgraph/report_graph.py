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
from typing import Dict, Any, List, Optional, TypedDict, Annotated
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage, SystemMessage
import google.generativeai as genai

# 로컬 langgraph 디렉토리가 패키지 langgraph와 충돌하지 않도록 처리
# 현재 디렉토리를 sys.path에서 제거하고 패키지 langgraph를 import
current_file_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_file_dir)
# sys.path에서 현재 langgraph 디렉토리와 부모 디렉토리 제거 (임시)
paths_to_remove = [current_file_dir, parent_dir]
original_path = sys.path[:]
for path in paths_to_remove:
    if path in sys.path:
        sys.path.remove(path)

try:
    # 패키지 langgraph import
    from langgraph.graph import StateGraph, END
    from langgraph.checkpoint.memory import MemorySaver
finally:
    # sys.path 복원
    sys.path[:] = original_path

# Tools import를 위해 경로 복원
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.survey_tool import get_survey
from tools.qdrant_search import qdrant_search
from tools.report_store import save_report
from tools.schemas import QdrantSearchInput, EvidenceItem

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


def invoke_llm_simple(prompt: str, system_prompt: str = "") -> str:
    """간단한 LLM 호출 (google.generativeai 직접 사용)"""
    if not GOOGLE_API_KEY:
        return "LLM이 초기화되지 않았습니다."
    
    try:
        if llm:
            messages = []
            if system_prompt:
                messages.append(SystemMessage(content=system_prompt))
            messages.append(HumanMessage(content=prompt))
            response = llm.invoke(messages)
            return response.content if hasattr(response, 'content') else str(response)
        else:
            # Fallback: google.generativeai 직접 사용
            if not genai_model_name:
                genai_model_name = "gemini-2.5-flash"
            model = genai.GenerativeModel(genai_model_name)
            full_prompt = f"{system_prompt}\n\n{prompt}" if system_prompt else prompt
            response = model.generate_content(full_prompt)
            return response.text
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
    retrieval_results: Dict[str, List[EvidenceItem]]  # 섹션별 검색 결과
    evidence_bundles: Dict[str, str]  # 섹션별 근거 요약
    section_drafts: Dict[str, str]  # 섹션별 초안
    final_report: Optional[Dict[str, Any]]
    citations: List[Dict[str, Any]]  # 인용 정보
    quality_flags: Dict[str, bool]  # 품질 플래그


# 목표 한글 매핑
OUTCOME_LABELS = {
    "wrinkle": "주름",
    "pigmentation": "색소",
    "hydration": "수분",
    "acne": "여드름",
    "redness": "홍조",
    "general_aging": "전체 노화",
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


# 노드 4: RetrieveEvidence (tool: qdrant_search) - 섹션별 검색
def retrieve_evidence(state: ReportState) -> ReportState:
    """섹션별 근거 검색"""
    print("[RetrieveEvidence] 근거 검색 시작")
    queries = state.get("section_queries", {})
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    
    retrieval_results = {}
    all_citations = []
    
    # 섹션별 검색 수행
    for section in sections:
        if section not in queries:
            continue
        
        query = queries[section]
        
        # 섹션별 topics 및 section_norm 매핑
        section_mapping = {
            "goals": {"section_norm": "general", "topics": survey.get("outcomes", [])},
            "sleep": {"section_norm": "sleep", "topics": ["sleep", "circadian"]},
            "uv": {"section_norm": "uv", "topics": ["uv", "photoaging"]},
            "lifestyle": {"section_norm": "lifestyle", "topics": ["lifestyle", "stress"]},
            "activity": {"section_norm": "activity", "topics": ["exercise", "metabolism"]},
        }
        
        mapping = section_mapping.get(section, {"section_norm": section, "topics": None})
        
        try:
            search_input = QdrantSearchInput(
                query=query,
                top_k=5,
                topics=mapping.get("topics"),
                section_norm=mapping.get("section_norm"),
                candidate_k=20,
                min_score=0.3
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
            
            print(f"  [{section}] {len(result.items)}개 근거 검색 완료")
        except Exception as e:
            print(f"  ⚠️ [{section}] 검색 실패: {e}")
            retrieval_results[section] = []
    
    # 중복 제거된 인용 정보
    unique_citations = []
    seen = set()
    for cit in all_citations:
        key = (cit["paper_id"], cit["chunk_id"])
        if key not in seen:
            seen.add(key)
            unique_citations.append(cit)
    
    print(f"✅ [RetrieveEvidence] 검색 완료 - 총 {len(unique_citations)}개 고유 인용")
    return {
        **state,
        "retrieval_results": retrieval_results,
        "citations": unique_citations
    }


# 노드 5: WriteSectionDraft (LLM)
def write_section_draft(state: ReportState) -> ReportState:
    """섹션별 초안 작성 (LLM)"""
    print("[WriteSectionDraft] 섹션 초안 작성 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    retrieval_results = state.get("retrieval_results", {})
    
    section_drafts = {}
    
    for section in sections:
        evidence_items = retrieval_results.get(section, [])
        
        # 근거 텍스트 수집
        evidence_texts = []
        for item in evidence_items:
            evidence_texts.append(f"[{item.paper_id}] {item.text}")
        
        evidence_summary = "\n\n".join(evidence_texts) if evidence_texts else "관련 근거가 없습니다."
        
        # 섹션별 프롬프트 생성
        section_prompts = {
            "goals": f"""다음 설문 데이터와 논문 근거를 바탕으로 "주요 목표 분석 및 개선 방안" 섹션을 작성하세요.

설문 데이터:
- 주요 목표: {', '.join([OUTCOME_LABELS.get(o, o) for o in survey.get('outcomes', [])])}
- 목표 연도: +{survey.get('target_years', 30)}년

논문 근거:
{evidence_summary}

다음 형식으로 작성:
1. 현재 상태 (설문 기반)
2. 논문 근거 요약 (근거 chunks 인용 포함)
3. 개선 권고안

한국어로 작성하세요.""",
            "sleep": f"""다음 설문 데이터와 논문 근거를 바탕으로 "수면 및 리듬" 섹션을 작성하세요.

설문 데이터:
- 평일 수면시간: {survey.get('sleep_hours_weekday')}시간
- 주말 수면시간: {survey.get('sleep_hours_weekend')}시간
- 수면의 질: {survey.get('sleep_quality_score')}/10점

논문 근거:
{evidence_summary}

다음 형식으로 작성:
1. 현재 상태 (설문 기반)
2. 논문 근거 요약 (근거 chunks 인용 포함)
3. 개선 권고안

한국어로 작성하세요.""",
            "uv": f"""다음 설문 데이터와 논문 근거를 바탕으로 "자외선 및 노화 관리" 섹션을 작성하세요.

설문 데이터:
- 야외 노출(10~16시): {survey.get('uv_exposure_10to16')}
- 선크림 사용 빈도: {survey.get('sunscreen_frequency')}

논문 근거:
{evidence_summary}

다음 형식으로 작성:
1. 현재 상태 (설문 기반)
2. 논문 근거 요약 (근거 chunks 인용 포함)
3. 개선 권고안

한국어로 작성하세요.""",
            "lifestyle": f"""다음 설문 데이터와 논문 근거를 바탕으로 "생활습관 관리" 섹션을 작성하세요.

설문 데이터:
- 흡연 상태: {survey.get('smoking_status')}
- 주당 음주일수: {survey.get('drinking_days_per_week')}
- 스트레스 점수: {survey.get('stress_score')}/10점

논문 근거:
{evidence_summary}

다음 형식으로 작성:
1. 현재 상태 (설문 기반)
2. 논문 근거 요약 (근거 chunks 인용 포함)
3. 개선 권고안

한국어로 작성하세요.""",
            "activity": f"""다음 설문 데이터와 논문 근거를 바탕으로 "활동 및 대사" 섹션을 작성하세요.

설문 데이터:
- 유산소 운동(주당): {survey.get('aerobic_weekly')}회
- 근력 운동(주당): {survey.get('resistance_weekly')}회

논문 근거:
{evidence_summary}

다음 형식으로 작성:
1. 현재 상태 (설문 기반)
2. 논문 근거 요약 (근거 chunks 인용 포함)
3. 개선 권고안

한국어로 작성하세요.""",
        }
        
        prompt = section_prompts.get(section, f"{section} 섹션을 작성하세요.\n\n논문 근거:\n{evidence_summary}")
        
        try:
            system_prompt = "당신은 건강 및 피부 관리 전문가입니다. 논문 근거를 바탕으로 구체적이고 실용적인 조언을 제공합니다."
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
    """최종 리포트 조립 (LLM)"""
    print("[AssembleReport] 최종 리포트 조립 시작")
    survey = state.get("survey", {})
    section_drafts = state.get("section_drafts", {})
    citations = state.get("citations", [])
    
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
        sections_text.append(f"## {title}\n\n{draft}")
    
    report_content = "\n\n".join(sections_text)
    
    # 최종 리포트 구조 생성
    final_report = {
        "sections": section_drafts,
        "citations": citations,
        "survey_summary": {
            "outcomes": survey.get("outcomes", []),
            "target_years": survey.get("target_years", 30),
        },
        "generated_at": None  # 나중에 저장 시점에 설정
    }
    
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
