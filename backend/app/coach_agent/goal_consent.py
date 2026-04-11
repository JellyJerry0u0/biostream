"""
사용자 동의 기반 적응형 목표 반영.

세션의 coach_pending_goal_updates 와 coach_agent_persisted 를 일관되게 갱신한다.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session as SaSession

from app.coach_agent.db_persistence import persist_user_coach_state
from app.coach_agent.memory_store import SessionDictCoachMemoryStore, parse_persisted, serialize_persisted
from app.coach_agent.schemas import GoalRevision, TargetHistoryEntry


def apply_goal_consent(
    session: Any,
    goal_id: str,
    accept: bool,
    revised_target: Optional[str] = None,
    db: Optional[SaSession] = None,
) -> Dict[str, Any]:
    pending: List[Dict[str, Any]] = list(
        getattr(session, "coach_pending_goal_updates", None) or []
    )
    proposal = next((p for p in pending if p.get("goal_id") == goal_id), None)

    if not proposal:
        return {
            "success": False,
            "error": "해당 목표 제안을 찾을 수 없습니다. 코치 모드에서 다시 대화해 주세요.",
        }

    store = SessionDictCoachMemoryStore(session)
    goals, hist, episodic, coaching = parse_persisted(store.load())

    goal_idx = next((i for i, g in enumerate(goals) if g.goal_id == goal_id), None)
    if goal_idx is None:
        return {"success": False, "error": "활성 목표를 찾을 수 없습니다."}

    g = goals[goal_idx]
    session.coach_pending_goal_updates = [p for p in pending if p.get("goal_id") != goal_id]

    if not accept:
        ng = g.model_copy(deep=True)
        ng.pending_user_approval = False
        ng.proposed_target = None
        goals[goal_idx] = ng
        store.save(serialize_persisted(goals, hist, episodic, coaching))
        if db:
            persist_user_coach_state(session, db)
        return {"success": True, "accepted": False}

    new_target = (revised_target or proposal.get("proposed_target") or "").strip()
    if not new_target:
        return {"success": False, "error": "새 목표 문구가 비어 있습니다."}

    rev = GoalRevision(
        revision_id=str(uuid.uuid4()),
        goal_id=goal_id,
        previous_target=g.current_target,
        new_target=new_target,
        reason=str(proposal.get("reason") or "코치 제안"),
        decided_by="user",
        pending_user_approval=False,
    )
    hist = list(hist)
    hist.append(rev)

    ng = g.model_copy(deep=True)
    ng.current_target = new_target
    ng.pending_user_approval = False
    ng.proposed_target = None
    ng.revision_reason = "사용자 동의로 목표 조정"
    ng.last_updated_at = datetime.now(timezone.utc)
    th = list(ng.target_history)
    th.append(
        TargetHistoryEntry(
            recorded_at=datetime.now(timezone.utc),
            target_description=new_target,
            unit=ng.unit,
        )
    )
    ng.target_history = th
    goals[goal_idx] = ng
    store.save(serialize_persisted(goals, hist, episodic, coaching))
    if db:
        persist_user_coach_state(session, db)
    return {"success": True, "accepted": True, "goal": ng.model_dump(mode="json")}
