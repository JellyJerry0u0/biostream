from typing import TypedDict
from langgraph.graph import StateGraph, END

# 상태 정의
class GraphState(TypedDict):
    query: str
    response: str

# 노드 함수들
def process_query(state: GraphState) -> GraphState:
    """쿼리를 처리하는 노드"""
    query = state["query"]
    # 간단한 처리: 쿼리를 대문자로 변환
    processed = query.upper()
    return {"query": query, "response": processed}

def generate_response(state: GraphState) -> GraphState:
    """응답을 생성하는 노드"""
    response = state["response"]
    # 추가 처리: 응답에 접미사 추가
    final_response = f"처리된 응답: {response}"
    return {"query": state["query"], "response": final_response}

# 그래프 생성
def create_basic_graph():
    workflow = StateGraph(GraphState)

    # 노드 추가
    workflow.add_node("process", process_query)
    workflow.add_node("respond", generate_response)

    # 엣지 추가
    workflow.set_entry_point("process")
    workflow.add_edge("process", "respond")
    workflow.add_edge("respond", END)

    # 그래프 컴파일
    app = workflow.compile()
    return app

# 사용 예제
if __name__ == "__main__":
    graph = create_basic_graph()
    initial_state = {"query": "안녕하세요", "response": ""}
    result = graph.invoke(initial_state)
    print(result)