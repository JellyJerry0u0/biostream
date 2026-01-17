# ai_service/workflow_graph.py

#RAG 파이프라인을 노드로 정의

from langgraph.graph import StateGraph, START, END
from langgraph.graph.state import CompiledStateGraph
from typing import TypedDict, Optional
import os

# 상태 정의 (워크플로우에서 전달할 데이터)
class RagState(TypedDict):
    query: str
    data: Optional[list] = None
    embeddings: Optional[list] = None
    search_results: Optional[list] = None
    evaluation: Optional[dict] = None

# 노드 함수들 (각 단계의 로직)
def load_data(state: RagState) -> RagState:
    # 데이터 로드 로직 (간단히 시뮬레이션)
    state["data"] = ["샘플 데이터 1", "샘플 데이터 2"]
    print("📥 데이터 로드 완료")
    return state

def embed_data(state: RagState) -> RagState:
    # 임베딩 생성 로직 (간단히 시뮬레이션)
    from core.embedder import BioEmbedder
    embedder = BioEmbedder()
    state["embeddings"] = [embedder.embed_text(text) for text in state["data"]]
    print("🔍 임베딩 생성 완료")
    return state

def search_vector(state: RagState) -> RagState:
    # 벡터 검색 로직 (간단히 시뮬레이션)
    state["search_results"] = ["결과 1", "결과 2"]
    print("🔎 벡터 검색 완료")
    return state

def evaluate_results(state: RagState) -> RagState:
    # 평가 로직 (간단히 시뮬레이션)
    state["evaluation"] = {"신뢰도": 0.85, "등급": "A"}
    print("📊 평가 완료")
    return state

# 그래프 구축
def build_graph() -> CompiledStateGraph:
    graph = StateGraph(RagState)
    
    # 노드 추가
    graph.add_node("load", load_data)
    graph.add_node("embed", embed_data)
    graph.add_node("search", search_vector)
    graph.add_node("evaluate", evaluate_results)
    
    # 엣지 추가 (흐름 정의)
    graph.add_edge(START, "load")
    graph.add_edge("load", "embed")
    graph.add_edge("embed", "search")
    graph.add_edge("search", "evaluate")
    graph.add_edge("evaluate", END)
    
    return graph.compile()

# 그래프 시각화 및 실행
if __name__ == "__main__":
    graph = build_graph()
    
    # 그래프 이미지 생성
    graph_image = graph.get_graph().draw_mermaid_png()
    with open("rag_workflow.png", "wb") as f:
        f.write(graph_image)
    print("✅ 그래프 이미지 생성: rag_workflow.png")
    
    # 샘플 실행
    initial_state = {"query": "노화 영향 분석"}
    result = graph.invoke(initial_state)
    print("실행 결과:", result)