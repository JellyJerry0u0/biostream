"""
코치 적응형 목표 동의 API (세션 기반 in-memory).
"""

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.committed_actions import get_current_user
from app.database import get_db
from app import models
from app.coach_agent.goal_consent import apply_goal_consent
from app.services.session_store import session_store

router = APIRouter(prefix="/api", tags=["Coach Goals"])


@router.get("/coach/active-goals")
def get_active_coach_goals(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    DB에 영속화된 코치 적응형 목표(active_goals) 목록.
    리포트에서 담은 committed_action(습관 카드)과는 별개 레이어.
    """
    row = (
        db.query(models.UserCoachAgentState)
        .filter(models.UserCoachAgentState.user_id == current_user.id)
        .first()
    )
    if not row or not row.state:
        return {"goals": []}
    st = row.state if isinstance(row.state, dict) else {}
    raw_goals = st.get("active_goals") or []
    out: list = []
    for g in raw_goals:
        if not isinstance(g, dict):
            continue
        out.append(
            {
                "goal_id": g.get("goal_id") or "",
                "domain": g.get("domain") or "general",
                "description": g.get("description") or "",
                "current_target": g.get("current_target") or "",
                "unit": g.get("unit"),
                "status": g.get("status") or "active",
                "pending_user_approval": bool(g.get("pending_user_approval")),
                "proposed_target": g.get("proposed_target"),
                "success_rate_7d": g.get("success_rate_7d"),
            }
        )
    return {"goals": out}


class GoalConsentBody(BaseModel):
    session_id: str = Field(..., min_length=4)
    goal_id: str = Field(..., min_length=1)
    accept: bool
    revised_target: Optional[str] = Field(
        default=None,
        description="동의 시 목표 문구를 사용자가 수정한 경우",
    )


@router.post("/coach/goals/consent")
def post_goal_consent(
    body: GoalConsentBody,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = session_store.get(body.session_id)
    if not session or session.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="세션을 찾을 수 없습니다.")
    result = apply_goal_consent(
        session,
        body.goal_id,
        body.accept,
        body.revised_target,
        db=db,
    )
    if not result.get("success"):
        raise HTTPException(status_code=400, detail=result.get("error", "처리 실패"))
    return result
