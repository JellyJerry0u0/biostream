"""
코치 에이전트 상태의 사용자 단위 DB 영속화 (PostgreSQL JSON).

세션 메모리는 WS 연결 동안의 캐시로 두고, 서버 재시작·다른 기기에서도 이어지게 한다.
"""

from __future__ import annotations

from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from app.models import UserCoachAgentState


def _state_without_pending(full: Dict[str, Any]) -> Dict[str, Any]:
    out = {k: v for k, v in full.items() if k != "pending_goal_updates"}
    return out


def hydrate_user_coach_state_if_cold(session_data: Any, db: Optional[Session]) -> None:
    """
    WS 세션에 아직 코치 스냅샷이 없을 때만 DB에서 채운다.
    (빈 dict는 falsy → 첫 코치 턴·재연결 직후에 로드)
    """
    if not db or not getattr(session_data, "user_id", None):
        return
    if getattr(session_data, "coach_agent_persisted", None):
        return
    row = (
        db.query(UserCoachAgentState)
        .filter(UserCoachAgentState.user_id == session_data.user_id)
        .first()
    )
    if not row or not row.state:
        return
    full = dict(row.state) if isinstance(row.state, dict) else {}
    session_data.coach_pending_goal_updates = list(full.get("pending_goal_updates") or [])
    session_data.coach_agent_persisted = _state_without_pending(full)


def persist_user_coach_state(session_data: Any, db: Optional[Session]) -> None:
    """세션의 coach_agent_persisted + pending_goal_updates 를 DB에 upsert."""
    if not db or not getattr(session_data, "user_id", None):
        return
    core = dict(getattr(session_data, "coach_agent_persisted", None) or {})
    full: Dict[str, Any] = {**core, "pending_goal_updates": list(getattr(session_data, "coach_pending_goal_updates", None) or [])}
    row = (
        db.query(UserCoachAgentState)
        .filter(UserCoachAgentState.user_id == session_data.user_id)
        .first()
    )
    if row:
        row.state = full
    else:
        db.add(UserCoachAgentState(user_id=session_data.user_id, state=full))
    db.commit()
