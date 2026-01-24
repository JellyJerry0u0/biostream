#langgraph.py에 정의한 BioStreamState를 기반으로 에이전트 전체 흐름 제어
#하는 LangGraph 뼈대 코드

#각 단계(Node)를 연결하고 데이터가 어떻게 흐르는지 정의

from typing import Dict
from langgraph.graph import StateGraph, END

# 1. 정의한 State 불러오기
from .langgraph_state import BioStreamState

# --- 각 노드(Node) 정의 (Placeholder) ---

def analyze_survey_node(state: BioStreamState):
    """설문 데이터를 분석하여 검색 쿼리를 생성합니다."""
    print("--- 노드: 설문 분석 및 쿼리 생성 ---")
    # 로직 예: LLM을 호출하여 state['user_inputs'] 기반 쿼리 추출
    return {"search_queries": ["예시 쿼리 1", "예시 쿼리 2"]}

def retrieve_rag_node(state: BioStreamState):
    """Qdrant에서 관련 논문 근거를 검색합니다."""
    print("--- 노드: RAG 지식 검색 ---")
    # 로직 예: BioEmbedder와 QdrantClient를 사용하여 컨텍스트 검색
    return {"retrieved_contexts": ["검색된 논문 내용 A", "검색된 논문 내용 B"]}

def assess_aging_node(state: BioStreamState):
    """논문 근거를 바탕으로 노화를 평가하고 시각적 묘사를 생성합니다."""
    print("--- 노드: 노화 영향 평가 및 시각화 묘사 ---")
    # 로직 예: LLM이 컨텍스트와 유저 입력을 결합하여 리포트와 묘사 작성
    return {
        "evaluation_report": "당신의 노화 점수는...",
        "visual_description": "10년 후 눈가 주름이 깊어지는 양상..."
    }

def generate_image_prompt_node(state: BioStreamState):
    """시각적 묘사를 이미지 생성용 프롬프트로 변환합니다."""
    print("--- 노드: 이미지 프롬프트 생성 ---")
    return {"image_prompt": "A photorealistic portrait showing aging effects..."}

def image_generation_node(state: BioStreamState):
    """외부 API를 통해 이미지를 생성합니다."""
    print("--- 노드: 최종 이미지 생성 ---")
    return {"image_url": "https://example.com/generated_image.png"}

# --- 그래프 구축 (Workflow) ---

# 1. State를 인자로 전달하여 그래프 초기화
workflow = StateGraph(BioStreamState)

# 2. 노드 추가
workflow.add_node("analyze_survey", analyze_survey_node)
workflow.add_node("retrieve_rag", retrieve_rag_node)
workflow.add_node("assess_aging", assess_aging_node)
workflow.add_node("generate_image_prompt", generate_image_prompt_node)
workflow.add_node("image_generation", image_generation_node)

# 3. 엣지 연결 (흐름 정의)
workflow.set_entry_point("analyze_survey") # 시작점
workflow.add_edge("analyze_survey", "retrieve_rag")
workflow.add_edge("retrieve_rag", "assess_aging")
workflow.add_edge("assess_aging", "generate_image_prompt")
workflow.add_edge("generate_image_prompt", "image_generation")
workflow.add_edge("image_generation", END) # 종료점

# 4. 그래프 컴파일
app = workflow.compile()

# --- 실행 테스트 ---
if __name__ == "__main__":
    initial_input = {
        "user_inputs": {"smoking": "heavy", "sleep": 5, "stress": "high"}
    }
    
    # 그래프 실행
    for output in app.stream(initial_input):
        print(output)