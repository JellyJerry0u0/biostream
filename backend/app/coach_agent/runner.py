"""
WebSocket 코치 파이프라인 진입점 — coach 엔진에서 호출.
"""

from __future__ import annotations

import asyncio
import traceback
from typing import Any, Dict

from app.coach_agent.graph import build_coach_agent_graph
from app.coach_agent.state import CoachAgentState
from app.services.coach_memory import (
    apply_memory_updates,
    extract_memory_updates,
    get_or_create_memory,
    save_memory_to_session,
)
from app.services.session_store import SessionData

from app.coach_agent.db_persistence import (
    hydrate_user_coach_state_if_cold,
    persist_user_coach_state,
)


async def run_coach_agent(
    session: SessionData,
    user_message: str,
    mode: str,
    report_ctx: Dict[str, Any],
    assistant_msg_id: str,
    send_json,
    db=None,
    snapshot_nudge_mode: bool = False,
):
    """
    LangGraph 코치 에이전트 실행 후 delta로 최종 응답을 전송.
    """
    try:
        if db and session.user_id:
            hydrate_user_coach_state_if_cold(session, db)

        memory = get_or_create_memory(session)
        mem_updates = extract_memory_updates(user_message)
        if mem_updates:
            apply_memory_updates(memory, mem_updates)
            save_memory_to_session(session, memory)
            ui_items = memory.get_memory_items_for_ui()
            if ui_items:
                await send_json({"type": "memory_update", "items": ui_items})

        initial: CoachAgentState = {
            "user_id": session.user_id or 0,
            "current_message": user_message,
            "conversation_history": session.get_history_for_prompt(),
            "profile": {},
            "recent_health_logs": [],
            "active_goals": [],
            "goal_history": [],
            "derived_metrics": {},
            "adherence_summary": {},
            "behavior_patterns": [],
            "coaching_memory": {},
            "episodic_memory": [],
            "missing_info": [],
            "supervisor_decision": {},
            "intervention_plan": {},
            "structured_response": {},
            "final_response": "",
            "report_ctx": report_ctx or {},
            "mode": mode,
            "session": session,
            "db": db,
            "send_json": send_json,
            "assistant_msg_id": assistant_msg_id,
            "snapshot_nudge_mode": snapshot_nudge_mode,
        }

        graph = build_coach_agent_graph()
        final_state = await graph.ainvoke(initial)

        plan = final_state.get("intervention_plan") or {}
        raw_updates = plan.get("recommended_goal_updates") or []
        pending: list = []
        for u in raw_updates:
            if isinstance(u, dict):
                pending.append(dict(u))
            elif hasattr(u, "model_dump"):
                pending.append(u.model_dump(mode="json"))
        session.coach_pending_goal_updates = pending
        if pending:
            await send_json(
                {
                    "type": "goal_proposals",
                    "assistant_message_id": assistant_msg_id,
                    "items": pending,
                }
            )

        full_response = (final_state.get("final_response") or "").strip()
        if not full_response:
            full_response = "지금은 답변을 만들기 어렵습니다. 잠시 후 다시 말씀해 주세요."
        # 스트리밍 UX: 문장 단위 chunk (토큰 스트리밍은 그래프 다중 LLM 호출과 분리)
        chunk_size = 28
        for i in range(0, len(full_response), chunk_size):
            await send_json(
                {
                    "type": "delta",
                    "assistant_message_id": assistant_msg_id,
                    "delta": full_response[i : i + chunk_size],
                }
            )
            await asyncio.sleep(0.01)

        session.add_turn("user", user_message)
        session.add_turn("assistant", full_response)
        save_memory_to_session(session, memory)

        from app.services.coach_service import (
            classify_intent,
            generate_action_items,
            extract_citations,
        )

        intent = classify_intent(user_message, mode)
        action_items = generate_action_items(intent, session, report_ctx)
        if action_items:
            await send_json(
                {
                    "type": "actions",
                    "assistant_message_id": assistant_msg_id,
                    "items": action_items,
                }
            )
        citations = extract_citations(report_ctx)
        if citations:
            await send_json(
                {
                    "type": "citations",
                    "assistant_message_id": assistant_msg_id,
                    "items": citations,
                }
            )

        await send_json({"type": "done", "assistant_message_id": assistant_msg_id})

        if db and session.user_id:
            persist_user_coach_state(session, db)

    except Exception as e:
        print(f"[CoachAgent] 오류: {e}")
        traceback.print_exc()
        await send_json(
            {
                "type": "error",
                "message": f"코치 모드 처리 중 오류: {str(e)[:100]}",
                "assistant_message_id": assistant_msg_id,
            }
        )
