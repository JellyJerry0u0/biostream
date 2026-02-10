"""
LangGraph Deep Coach 그래프
- report_graph.py와 동일한 StateGraph 패턴
- LLM이 tool calling을 스스로 결정하는 agentic 구조
- 노드: prepare_context → agent → (tool 실행 ↔ agent 반복) → post_process

스트리밍:
  graph.astream_events() 로 LLM 토큰 이벤트를 WS delta로 전송
  도구 호출 시 tool_status 이벤트 전송
"""

import os
import json
import uuid
import traceback
from typing import Dict, Any, List, Optional, TypedDict, Annotated, Sequence
from enum import Enum

from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode
from langchain_core.messages import (
    SystemMessage,
    HumanMessage,
    AIMessage,
    BaseMessage,
    ToolMessage,
)

from app.services.session_store import SessionData
from app.services.coach_memory import (
    CoachMemory,
    get_or_create_memory,
    save_memory_to_session,
    extract_memory_updates,
    apply_memory_updates,
)


# ══════════════════════════════════════════════
#  State 정의
# ══════════════════════════════════════════════

def _add_messages(
    existing: Sequence[BaseMessage],
    new: Sequence[BaseMessage],
) -> Sequence[BaseMessage]:
    """메시지 리스트 누적 리듀서"""
    return list(existing) + list(new)


class DeepCoachState(TypedDict):
    """Deep Coach 그래프 상태"""
    messages: Annotated[Sequence[BaseMessage], _add_messages]
    session: SessionData
    user_message: str
    mode: str
    report_ctx: Dict[str, Any]
    memory: CoachMemory
    assistant_msg_id: str
    send_json: Any  # async callable
    db: Any
    full_response: str  # 최종 응답 텍스트 (post_process에서 수집)


# ══════════════════════════════════════════════
#  LLM + Tool 초기화
# ══════════════════════════════════════════════

def _get_llm_with_tools(tools):
    """Gemini LLM에 tools를 바인딩하여 반환"""
    from langchain_google_genai import ChatGoogleGenerativeAI

    model_name = os.getenv("COACH_LLM_MODEL", "gemini-2.0-flash")
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")

    if not api_key:
        raise ValueError("GEMINI_API_KEY 또는 GOOGLE_API_KEY가 설정되지 않았습니다.")

    llm = ChatGoogleGenerativeAI(
        model=model_name,
        google_api_key=api_key,
        streaming=True,
        temperature=0.7,
        max_output_tokens=1024,
    )

    if tools:
        return llm.bind_tools(tools)
    return llm


def _get_registry_tools(context=None):
    """레지스트리에서 LangChain 도구 목록을 가져옴 (내부 도구)"""
    from app.tools.registry import create_default_registry, ToolContext

    ctx = context or ToolContext()
    registry = create_default_registry()
    return registry.to_langchain_tools(ctx)


async def _get_mcp_tools() -> List:
    """
    MCP 서버에서 도구를 가져옴 (외부 도구).

    향후 외부 MCP 도구를 연동할 때 이 함수를 구현한다.
    langchain-mcp-adapters 패키지를 사용하여 MCP 프로토콜로 도구를 가져온다.

    구현 예시:
        from langchain_mcp_adapters.client import MultiServerMCPClient

        url = os.getenv("MCP_SERVER_URL", "http://localhost:8001/mcp")
        client = MultiServerMCPClient({
            "biostream": {"url": url, "transport": "http"}
        })
        return await client.get_tools()

    필요 패키지: pip install langchain-mcp-adapters
    """
    return []


async def get_all_tools(context=None) -> List:
    """
    Deep Coach에서 사용할 전체 도구 목록을 반환.
    내부 도구(in-process) + MCP 도구(외부)를 하나로 합친 단일 진입점.

    - 내부 도구: registry 도구 + search_evidence (빠름, 0ms 오버헤드)
    - MCP 도구: 향후 외부 서비스 연동 시 추가 (HTTP 호출)

    새 도구를 추가할 때:
      - 내부 함수 → registry.py에 BaseTool 등록
      - 외부 MCP → mcp_server/server.py에 @mcp.tool() 등록 + _get_mcp_tools() 활성화
    """
    tools = []

    # 1) 내부 도구 (in-process, 빠름)
    tools += _get_registry_tools(context)
    tools.append(_create_search_evidence_tool())

    # 2) MCP 도구 (향후 외부 도구 연동 시 주석 해제)
    # mcp_tools = await _get_mcp_tools()
    # tools += mcp_tools

    return tools


# ══════════════════════════════════════════════
#  시스템 프롬프트 (Deep 모드 전용)
# ══════════════════════════════════════════════

_DEEP_SYSTEM_PROMPT = """당신은 '손 안의 피부노화 관리사' — 사용자의 피부 건강 리포트를 기반으로 맞춤형 생활습관 코칭을 제공하는 AI 코치입니다.
당신은 심화 코치 모드로 동작 중입니다. 필요에 따라 도구를 사용하여 더 정확하고 전문적인 답변을 제공할 수 있습니다.

사용 가능한 도구:
- search_evidence: 논문 근거 RAG 검색. 사용자가 근거나 논문을 요청하면 사용하세요.
- save_goal: 사용자의 피부 관리 목표를 저장합니다.
- generate_today_plan: 오늘의 맞춤 액션 플랜을 생성합니다.
- fetch_report_summary: 리포트의 상세 섹션을 조회합니다.

도구 사용 원칙:
- 단순한 질문에는 도구 없이 직접 답하세요 (더 빠릅니다).
- 논문 근거, 상세 데이터, 플랜 생성이 필요할 때만 도구를 사용하세요.
- 도구 결과를 바탕으로 자연스러운 답변을 생성하세요.

답변 구조:
1. 결론 1줄 — 지금/오늘 할 일을 명확하게 (첫 줄에 반드시)
2. 이유 — 리포트 카드/근거 기반, 2~3문장 이내
3. 오늘의 액션 2~3개 — 각각 시간대와 난이도(쉬움/보통/도전) 포함
4. 주의사항 — 자극/금기/측정 관련, 1~2줄

원칙:
- 첫 줄(결론)을 최대한 빨리 출력하세요.
- 짧고 실용적인 답변 우선. 3~5줄이면 충분합니다.
- 의학적 진단은 하지 마세요. 생활습관 개선에 집중하세요.
- 리포트 데이터가 있으면 반드시 언급하되, 지나치게 길게 인용하지 마세요.
- 사용자의 목표·제약·민감성을 항상 고려하세요.
- 한국어로 답변하세요.
- 절대 마크다운 문법(**, ##, -, ``` 등)을 사용하지 마세요. 모바일 채팅 앱에 표시되므로 일반 텍스트로만 답변하세요.
"""


# ══════════════════════════════════════════════
#  RAG 검색 도구 (Qdrant 기반)
# ══════════════════════════════════════════════

def _create_search_evidence_tool():
    """RAG 검색 도구를 LangChain StructuredTool로 생성"""
    from langchain_core.tools import tool
    from pydantic import BaseModel, Field

    class SearchEvidenceInput(BaseModel):
        query: str = Field(..., description="검색할 질의 텍스트")
        top_k: int = Field(3, description="반환할 결과 수")

    @tool(args_schema=SearchEvidenceInput)
    def search_evidence(query: str, top_k: int = 3) -> str:
        """논문 근거를 검색합니다. 피부 관련 논문에서 근거를 찾아줍니다."""
        try:
            import sys
            app_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            if app_root not in sys.path:
                sys.path.append(app_root)

            from tools.qdrant_search import qdrant_search
            from tools.schemas import QdrantSearchInput

            search_input = QdrantSearchInput(
                query=query[:200],
                top_k=top_k,
                min_score=0.2,
                candidate_k=30,
            )
            result = qdrant_search(search_input)

            if result.items:
                texts = []
                for item in result.items[:top_k]:
                    texts.append(f"[{item.paper_id}] {item.text[:300]}")
                return "\n---\n".join(texts)
            return "관련 근거를 찾지 못했습니다."
        except Exception as e:
            return f"검색 오류: {str(e)[:100]}"

    return search_evidence


# ══════════════════════════════════════════════
#  그래프 노드
# ══════════════════════════════════════════════

def prepare_context(state: DeepCoachState) -> Dict[str, Any]:
    """
    prepare 노드: 시스템 프롬프트 + 히스토리 + 리포트 컨텍스트 → messages 구성
    """
    session = state["session"]
    user_message = state["user_message"]
    mode = state["mode"]
    report_ctx = state["report_ctx"]
    memory = state["memory"]

    # 시스템 프롬프트 구성
    system = _DEEP_SYSTEM_PROMPT

    # 코치 메모리 요약
    memory_summary = memory.to_prompt_summary()
    if memory_summary and memory_summary != "(메모리 없음)":
        system += f"\n\n## 사용자 메모리\n{memory_summary}"

    # 리포트 컨텍스트
    if report_ctx.get("has_report"):
        system += f"\n\n## 사용자 리포트 요약\n{report_ctx.get('summary_text', '')[:2000]}"

    # 메시지 구성
    messages: List[BaseMessage] = [SystemMessage(content=system)]

    # 히스토리
    for turn in session.get_history_for_prompt():
        if turn["role"] == "user":
            messages.append(HumanMessage(content=turn["content"]))
        elif turn["role"] == "assistant":
            messages.append(AIMessage(content=turn["content"]))

    # 현재 사용자 메시지
    messages.append(HumanMessage(content=user_message))

    return {"messages": messages}


def should_use_tools(state: DeepCoachState) -> str:
    """
    조건 분기: 마지막 AI 메시지가 tool_call을 포함하면 'tools', 아니면 'respond'
    """
    messages = state["messages"]
    last = messages[-1] if messages else None

    if last and hasattr(last, "tool_calls") and last.tool_calls:
        return "tools"
    return "respond"


async def agent_node(state: DeepCoachState) -> Dict[str, Any]:
    """
    agent 노드: LLM 호출 (tool_calls 포함 가능)
    """
    from app.tools.registry import ToolContext

    context = ToolContext(
        user_id=state["session"].user_id,
        session_id=state["session"].session_id,
        report_id=state["session"].report_id,
    )

    all_tools = await get_all_tools(context)
    llm = _get_llm_with_tools(all_tools)

    response = await llm.ainvoke(state["messages"])
    return {"messages": [response]}


async def tool_node_with_status(state: DeepCoachState) -> Dict[str, Any]:
    """
    tool 실행 노드: 도구 호출 + tool_status 이벤트 전송
    """
    send_json = state["send_json"]
    assistant_msg_id = state["assistant_msg_id"]
    messages = state["messages"]
    last = messages[-1]

    tool_messages = []

    if hasattr(last, "tool_calls") and last.tool_calls:
        # 도구 목록 준비 (get_all_tools 단일 진입점)
        from app.tools.registry import ToolContext
        context = ToolContext(
            user_id=state["session"].user_id,
            session_id=state["session"].session_id,
            report_id=state["session"].report_id,
        )
        all_tools = await get_all_tools(context)
        tools_by_name = {t.name: t for t in all_tools}

        for tc in last.tool_calls:
            tool_name = tc["name"]

            # tool_status: running 전송
            try:
                await send_json({
                    "type": "tool_status",
                    "assistant_message_id": assistant_msg_id,
                    "tool": tool_name,
                    "status": "running",
                })
            except Exception:
                pass

            # 도구 실행
            try:
                tool_fn = tools_by_name.get(tool_name)
                if tool_fn:
                    result = await tool_fn.ainvoke(tc["args"])
                else:
                    result = f"도구를 찾을 수 없음: {tool_name}"
            except Exception as e:
                result = f"도구 실행 오류: {str(e)[:100]}"
                # tool_status: error 전송
                try:
                    await send_json({
                        "type": "tool_status",
                        "assistant_message_id": assistant_msg_id,
                        "tool": tool_name,
                        "status": "error",
                    })
                except Exception:
                    pass

            # tool_status: done 전송
            try:
                await send_json({
                    "type": "tool_status",
                    "assistant_message_id": assistant_msg_id,
                    "tool": tool_name,
                    "status": "done",
                })
            except Exception:
                pass

            tool_messages.append(
                ToolMessage(content=str(result), tool_call_id=tc["id"])
            )

    return {"messages": tool_messages}


async def post_process(state: DeepCoachState) -> Dict[str, Any]:
    """
    post_process 노드: 최종 AI 응답 텍스트 수집
    """
    messages = state["messages"]

    # 마지막 AI 메시지에서 텍스트 수집
    full_response = ""
    for msg in reversed(messages):
        if isinstance(msg, AIMessage) and msg.content and not (hasattr(msg, "tool_calls") and msg.tool_calls):
            full_response = msg.content
            break

    return {"full_response": full_response}


# ══════════════════════════════════════════════
#  그래프 조립
# ══════════════════════════════════════════════

def create_deep_coach_graph():
    """Deep Coach LangGraph 워크플로우 생성"""
    workflow = StateGraph(DeepCoachState)

    workflow.add_node("prepare_context", prepare_context)
    workflow.add_node("agent", agent_node)
    workflow.add_node("tools", tool_node_with_status)
    workflow.add_node("post_process", post_process)

    workflow.set_entry_point("prepare_context")
    workflow.add_edge("prepare_context", "agent")

    # agent → tool 호출이 있으면 tools, 없으면 post_process
    workflow.add_conditional_edges(
        "agent",
        should_use_tools,
        {"tools": "tools", "respond": "post_process"},
    )

    # tools → agent (도구 결과로 다시 LLM 호출)
    workflow.add_edge("tools", "agent")
    workflow.add_edge("post_process", END)

    return workflow.compile()


# ══════════════════════════════════════════════
#  메인 실행 함수
# ══════════════════════════════════════════════

async def run_deep_coach(
    session: SessionData,
    user_message: str,
    mode: str,
    report_ctx: Dict[str, Any],
    assistant_msg_id: str,
    send_json,
    db=None,
):
    """
    Deep Coach 실행 — 스트리밍 + tool calling

    coach_service에서 engine=="deep" 일 때 호출됨.
    """
    try:
        # 메모리 로드 & 업데이트
        memory = get_or_create_memory(session)
        mem_updates = extract_memory_updates(user_message)
        if mem_updates:
            apply_memory_updates(memory, mem_updates)
            save_memory_to_session(session, memory)

            ui_items = memory.get_memory_items_for_ui()
            if ui_items:
                await send_json({
                    "type": "memory_update",
                    "items": ui_items,
                })

        # 그래프 초기 상태
        initial_state: DeepCoachState = {
            "messages": [],
            "session": session,
            "user_message": user_message,
            "mode": mode,
            "report_ctx": report_ctx,
            "memory": memory,
            "assistant_msg_id": assistant_msg_id,
            "send_json": send_json,
            "db": db,
            "full_response": "",
        }

        graph = create_deep_coach_graph()

        # astream_events로 스트리밍
        full_response = ""
        streamed = False

        async for event in graph.astream_events(initial_state, version="v2"):
            kind = event.get("event", "")

            # LLM 스트리밍 토큰
            if kind == "on_chat_model_stream":
                chunk = event.get("data", {}).get("chunk")
                if chunk and hasattr(chunk, "content") and chunk.content:
                    # tool_calls 중인 경우 텍스트는 보통 비어있으므로 체크
                    text = chunk.content
                    if text and isinstance(text, str):
                        await send_json({
                            "type": "delta",
                            "assistant_message_id": assistant_msg_id,
                            "delta": text,
                        })
                        full_response += text
                        streamed = True

        # 스트리밍 안 됐으면 최종 상태에서 응답 추출
        if not streamed:
            # 그래프를 한 번 더 실행해서 최종 상태를 얻음 (이미 astream_events에서 실행됨)
            # full_response가 비어있으면 폴백
            if not full_response:
                full_response = "죄송합니다. 응답 생성에 실패했습니다. 다시 시도해 주세요."
                await send_json({
                    "type": "delta",
                    "assistant_message_id": assistant_msg_id,
                    "delta": full_response,
                })

        # 히스토리 저장
        session.add_turn("user", user_message)
        session.add_turn("assistant", full_response)
        save_memory_to_session(session, memory)

        # 액션 아이템 (Deep 모드에서는 LLM이 도구를 통해 플랜을 생성하므로 기본 액션만)
        from app.services.coach_service import (
            classify_intent,
            generate_action_items,
            extract_citations,
        )
        intent = classify_intent(user_message, mode)
        action_items = generate_action_items(intent, session, report_ctx)
        if action_items:
            await send_json({
                "type": "actions",
                "assistant_message_id": assistant_msg_id,
                "items": action_items,
            })

        citations = extract_citations(report_ctx)
        if citations:
            await send_json({
                "type": "citations",
                "assistant_message_id": assistant_msg_id,
                "items": citations,
            })

        # Done
        await send_json({
            "type": "done",
            "assistant_message_id": assistant_msg_id,
        })

    except Exception as e:
        print(f"[DeepCoach] 오류: {e}")
        traceback.print_exc()
        await send_json({
            "type": "error",
            "message": f"심화 코치 처리 중 오류: {str(e)[:100]}",
            "assistant_message_id": assistant_msg_id,
        })
