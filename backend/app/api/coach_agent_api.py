"""
코치 에이전트 헬스·데모 HTTP 엔드포인트.

프로덕션에서는 데모 경로를 끄거나 인증을 붙이는 것을 권장한다.
"""

import os
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/coach", tags=["Coach Agent"])


@router.get("/agent/graph-ok")
def coach_agent_graph_ok():
    """LangGraph 그래프 컴파일 스모크."""
    from app.coach_agent.graph import build_coach_agent_graph

    build_coach_agent_graph()
    return {"ok": True}


class DemoTurnRequest(BaseModel):
    message: str = Field(default="요즘 야근 때문에 잠이 부족해요")
    user_id: Optional[int] = Field(default=None, description="없으면 익명 데모(컨텍스트 최소)")


@router.post("/agent/demo-turn")
async def coach_agent_demo_turn(body: DemoTurnRequest):
    """
    DB 없이 휴리스틱 LLM으로 한 턴 실행 (로컬·CI).

    환경변수 COACH_AGENT_DEMO_ENABLED=1 일 때만 허용.
    """
    if os.getenv("COACH_AGENT_DEMO_ENABLED", "").lower() not in ("1", "true", "yes"):
        raise HTTPException(status_code=404, detail="데모 비활성화")

    from app.coach_agent.graph import build_coach_agent_graph
    from app.coach_agent.state import CoachAgentState
    from app.services.session_store import SessionData

    session = SessionData(session_id="demo-agent", user_id=body.user_id)
    initial: CoachAgentState = {
        "user_id": body.user_id or 0,
        "current_message": body.message,
        "conversation_history": [],
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
        "report_ctx": {},
        "mode": "coach",
        "session": session,
        "db": None,
        "send_json": None,
        "assistant_msg_id": "demo",
    }
    graph = build_coach_agent_graph()
    out = await graph.ainvoke(initial)
    return {
        "final_response": out.get("final_response"),
        "supervisor_decision": out.get("supervisor_decision"),
        "derived_metrics": out.get("derived_metrics"),
        "intervention_plan": out.get("intervention_plan"),
    }
