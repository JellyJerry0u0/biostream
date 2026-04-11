"""코치 인앱 넛지(스냅샷 최초 저장 등) 조회·소비"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.committed_actions import get_current_user
from app.database import get_db
from app import models

router = APIRouter(prefix="/api/coach", tags=["Coach Inbox"])


def _latest_pending_nudge_row(db: Session, user_id: int):
    return (
        db.query(models.CoachInAppNudge)
        .filter(
            models.CoachInAppNudge.user_id == user_id,
            models.CoachInAppNudge.consumed_at.is_(None),
        )
        .order_by(models.CoachInAppNudge.created_at.desc())
        .first()
    )


@router.get("/pending-nudge")
def peek_pending_coach_nudge(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    미소비 코치 메시지 1건 조회만 (소비하지 않음).
    UI에 붙인 뒤 POST /pending-nudge/consume 로 소비한다.
    """
    row = _latest_pending_nudge_row(db, current_user.id)
    if not row:
        return {"has_pending": False}
    return {"has_pending": True, "body": row.body, "nudge_id": row.id}


@router.post("/pending-nudge/consume")
def consume_pending_coach_nudge(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """peek으로 본 최신 미소비 넛지 1건을 소비 처리."""
    row = _latest_pending_nudge_row(db, current_user.id)
    if not row:
        return {"ok": False, "consumed": False}
    row.consumed_at = datetime.now(timezone.utc)
    db.add(row)
    db.commit()
    return {"ok": True, "consumed": True}
