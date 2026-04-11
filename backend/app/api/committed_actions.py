"""
습관 코칭 API
- POST /api/committed-actions: 리포트 행동을 생활습관으로 저장
- GET /api/committed-actions: 내 생활습관 목록 + 저장 한도(habit_quota)
- PATCH /api/committed-actions/{id}: 생활습관 제목/설명 업데이트 (개인화 수락)
- POST /api/committed-actions/{id}/check-in: 일별 체크인 (했어요/못했어요)
- GET /api/committed-actions/{id}/check-ins: 시계열 조회
- POST /api/committed-actions/{id}/retire: 생활습관 제거(슬롯 비움)
- POST /api/committed-actions/{id}/personalize: 개인화 재생성 (거절 후 1회)
"""

import os
from datetime import date, datetime, timedelta
from typing import Optional, List
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app import models

router = APIRouter(prefix="/api", tags=["Committed Actions"])


def _max_active_committed_habits() -> int:
    raw = os.getenv("MAX_ACTIVE_COMMITTED_HABITS", "12").strip()
    try:
        n = int(raw)
        return max(1, min(n, 50))
    except ValueError:
        return 12


def _count_active_committed(db: Session, user_id: int) -> int:
    return (
        db.query(models.UserCommittedAction)
        .filter(
            models.UserCommittedAction.user_id == user_id,
            models.UserCommittedAction.status == "active",
        )
        .count()
    )


def _habit_quota_payload(db: Session, user_id: int) -> dict:
    cap = _max_active_committed_habits()
    n = _count_active_committed(db, user_id)
    return {"max": cap, "active_count": n}


# ── 의존성 ──

def get_current_user(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
) -> models.User:
    from app.auth.security import verify_token

    if not authorization:
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")
    token = authorization.replace("Bearer ", "").strip()
    email = verify_token(token)
    if not email:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="사용자를 찾을 수 없습니다.")
    return user


# ── 스키마 ──

class CommitActionBody(BaseModel):
    lifestyle_id: int
    section_key: str
    action_title: str
    action_detail: Optional[str] = None


class UpdateActionBody(BaseModel):
    action_title: str
    action_detail: Optional[str] = None


class CheckInBody(BaseModel):
    check_date: str  # YYYY-MM-DD
    completed: bool  # True=했어요, False=못했어요
    note: Optional[str] = None


# ── 엔드포인트 ──

@router.post("/committed-actions")
def create_committed_action(
    body: CommitActionBody,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """리포트 행동을 생활습관으로 저장 (전역 활성 개수 상한)"""
    lifestyle = db.query(models.Lifestyle).filter(
        models.Lifestyle.id == body.lifestyle_id,
        models.Lifestyle.user_id == current_user.id,
    ).first()
    if not lifestyle:
        raise HTTPException(status_code=404, detail="해당 lifestyle을 찾을 수 없습니다.")

    existing = db.query(models.UserCommittedAction).filter(
        models.UserCommittedAction.user_id == current_user.id,
        models.UserCommittedAction.lifestyle_id == body.lifestyle_id,
        models.UserCommittedAction.action_title == body.action_title.strip(),
        models.UserCommittedAction.status == "active",
    ).first()
    if existing:
        return {
            "success": True,
            "message": "이미 추가한 생활습관입니다.",
            "committed_action": _serialize_action(existing),
            "habit_quota": _habit_quota_payload(db, current_user.id),
        }

    cap = _max_active_committed_habits()
    active_n = _count_active_committed(db, current_user.id)
    if active_n >= cap:
        raise HTTPException(
            status_code=400,
            detail=(
                f"생활습관은 최대 {cap}개까지 저장할 수 있습니다. "
                "홈·오늘의 나에서 기존 습관을 정리한 뒤 다시 시도해 주세요."
            ),
        )

    action = models.UserCommittedAction(
        user_id=current_user.id,
        lifestyle_id=body.lifestyle_id,
        section_key=body.section_key,
        action_title=body.action_title.strip(),
        action_detail=body.action_detail.strip() if body.action_detail else None,
        status="active",
    )
    db.add(action)
    db.commit()
    db.refresh(action)

    return {
        "success": True,
        "message": "생활습관에 추가했습니다.",
        "committed_action": _serialize_action(action),
        "habit_quota": _habit_quota_payload(db, current_user.id),
    }


@router.get("/committed-actions")
def list_committed_actions(
    lifestyle_id: Optional[int] = None,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """내 습관 목록 (선택 시 lifestyle_id로 필터)"""
    q = db.query(models.UserCommittedAction).filter(
        models.UserCommittedAction.user_id == current_user.id,
        models.UserCommittedAction.status == "active",
    )
    if lifestyle_id is not None:
        q = q.filter(models.UserCommittedAction.lifestyle_id == lifestyle_id)

    actions = q.order_by(models.UserCommittedAction.committed_at.desc()).all()
    today_str = date.today().isoformat()

    result = []
    for a in actions:
        item = _serialize_action(a)
        today_check = next(
            (c for c in a.check_ins if c.check_date.isoformat() == today_str),
            None,
        )
        item["today_completed"] = today_check.completed if today_check else None
        item["today_check_in_id"] = today_check.id if today_check else None
        result.append(item)

    return {
        "success": True,
        "committed_actions": result,
        "habit_quota": _habit_quota_payload(db, current_user.id),
    }


@router.post("/committed-actions/{action_id}/check-in")
def upsert_check_in(
    action_id: int,
    body: CheckInBody,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """일별 체크인 (했어요/못했어요) - 같은 날짜면 upsert"""
    action = db.query(models.UserCommittedAction).filter(
        models.UserCommittedAction.id == action_id,
        models.UserCommittedAction.user_id == current_user.id,
    ).first()
    if not action:
        raise HTTPException(status_code=404, detail="습관을 찾을 수 없습니다.")

    try:
        check_date = date.fromisoformat(body.check_date)
    except ValueError:
        raise HTTPException(status_code=422, detail="check_date는 YYYY-MM-DD 형식이어야 합니다.")

    existing = db.query(models.ActionCheckIn).filter(
        models.ActionCheckIn.committed_action_id == action_id,
        models.ActionCheckIn.check_date == check_date,
    ).first()

    if existing:
        existing.completed = body.completed
        existing.note = body.note
        db.commit()
        db.refresh(existing)
        return {
            "success": True,
            "message": "체크인 정보가 수정되었습니다.",
            "check_in": _serialize_check_in(existing),
        }

    check_in = models.ActionCheckIn(
        committed_action_id=action_id,
        check_date=check_date,
        completed=body.completed,
        note=body.note,
    )
    db.add(check_in)
    db.commit()
    db.refresh(check_in)

    return {
        "success": True,
        "message": "체크인되었습니다.",
        "check_in": _serialize_check_in(check_in),
    }


@router.get("/committed-actions/check-ins/summary")
def get_all_habits_check_ins_summary(
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """전체 습관의 날짜별 체크인 요약 (today_me 시계열/캘린더용)"""
    if not from_date:
        from_date = (date.today() - timedelta(days=30)).isoformat()
    if not to_date:
        to_date = date.today().isoformat()

    try:
        fd = date.fromisoformat(from_date)
        td = date.fromisoformat(to_date)
    except ValueError:
        raise HTTPException(status_code=422, detail="날짜 형식은 YYYY-MM-DD여야 합니다.")

    actions = db.query(models.UserCommittedAction).filter(
        models.UserCommittedAction.user_id == current_user.id,
        models.UserCommittedAction.status == "active",
    ).all()

    action_ids = [a.id for a in actions]
    if not action_ids:
        return {
            "success": True,
            "habits": [],
            "check_ins_by_date": {},
            "date_range": {"from": from_date, "to": to_date},
            "habit_quota": _habit_quota_payload(db, current_user.id),
        }

    check_ins = (
        db.query(models.ActionCheckIn)
        .filter(
            models.ActionCheckIn.committed_action_id.in_(action_ids),
            models.ActionCheckIn.check_date >= fd,
            models.ActionCheckIn.check_date <= td,
        )
        .order_by(models.ActionCheckIn.check_date.asc())
        .all()
    )

    habits = [_serialize_action(a) for a in actions]
    by_date = {}
    for c in check_ins:
        d = c.check_date.isoformat()
        if d not in by_date:
            by_date[d] = []
        action_title = next(
            (a.action_title for a in actions if a.id == c.committed_action_id),
            "",
        )
        by_date[d].append({
            "check_in_id": c.id,
            "committed_action_id": c.committed_action_id,
            "action_title": action_title,
            "completed": c.completed,
            "note": c.note,
        })

    return {
        "success": True,
        "habits": habits,
        "check_ins_by_date": by_date,
        "date_range": {"from": from_date, "to": to_date},
        "habit_quota": _habit_quota_payload(db, current_user.id),
    }


@router.patch("/committed-actions/{action_id}")
def update_committed_action(
    action_id: int,
    body: UpdateActionBody,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """개인화 수락 시 생활습관 제목/설명을 업데이트합니다."""
    action = db.query(models.UserCommittedAction).filter(
        models.UserCommittedAction.id == action_id,
        models.UserCommittedAction.user_id == current_user.id,
        models.UserCommittedAction.status == "active",
    ).first()
    if not action:
        raise HTTPException(status_code=404, detail="습관을 찾을 수 없습니다.")

    action.action_title = body.action_title.strip()
    action.action_detail = body.action_detail.strip() if body.action_detail else None
    db.commit()
    db.refresh(action)
    return {
        "success": True,
        "message": "생활습관이 업데이트되었습니다.",
        "committed_action": _serialize_action(action),
    }


@router.post("/committed-actions/{action_id}/personalize")
async def personalize_committed_action(
    action_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """생활습관 개인화를 1회 재생성합니다 (거절 후 재시도)."""
    from app.models import Lifestyle, Report
    from app.coach_agent.action_plan import personalize_single_habit

    action = db.query(models.UserCommittedAction).filter(
        models.UserCommittedAction.id == action_id,
        models.UserCommittedAction.user_id == current_user.id,
        models.UserCommittedAction.status == "active",
    ).first()
    if not action:
        raise HTTPException(status_code=404, detail="습관을 찾을 수 없습니다.")

    # 최신 lifestyle/report 로드
    lifestyle = (
        db.query(Lifestyle)
        .filter(Lifestyle.user_id == current_user.id)
        .order_by(Lifestyle.created_at.desc())
        .first()
    )
    report_data = None
    if lifestyle:
        report = (
            db.query(Report)
            .filter(Report.lifestyle_id == lifestyle.id)
            .order_by(Report.generated_at.desc())
            .first()
        )
        if report and report.report:
            try:
                import json as _json
                report_data = _json.loads(report.report) if isinstance(report.report, str) else report.report
            except Exception:
                pass

    proposal = await personalize_single_habit(action, current_user, lifestyle, report_data)
    return {"success": True, "proposal": proposal}


@router.post("/committed-actions/{action_id}/retire")
def retire_committed_action(
    action_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """생활습관에서 제거(슬롯 비움). status → abandoned, 이후 새로 저장 가능."""
    action = db.query(models.UserCommittedAction).filter(
        models.UserCommittedAction.id == action_id,
        models.UserCommittedAction.user_id == current_user.id,
    ).first()
    if not action:
        raise HTTPException(status_code=404, detail="습관을 찾을 수 없습니다.")
    if action.status != "active":
        return {
            "success": True,
            "message": "이미 정리된 생활습관입니다.",
            "habit_quota": _habit_quota_payload(db, current_user.id),
        }
    action.status = "abandoned"
    db.commit()
    db.refresh(action)
    return {
        "success": True,
        "message": "생활습관에서 제거했습니다.",
        "habit_quota": _habit_quota_payload(db, current_user.id),
    }


@router.get("/committed-actions/{action_id}/check-ins")
def list_check_ins(
    action_id: int,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """습관별 시계열 조회 (날짜 범위)"""
    action = db.query(models.UserCommittedAction).filter(
        models.UserCommittedAction.id == action_id,
        models.UserCommittedAction.user_id == current_user.id,
    ).first()
    if not action:
        raise HTTPException(status_code=404, detail="습관을 찾을 수 없습니다.")

    q = db.query(models.ActionCheckIn).filter(
        models.ActionCheckIn.committed_action_id == action_id,
    )

    if from_date:
        try:
            fd = date.fromisoformat(from_date)
            q = q.filter(models.ActionCheckIn.check_date >= fd)
        except ValueError:
            pass
    if to_date:
        try:
            td = date.fromisoformat(to_date)
            q = q.filter(models.ActionCheckIn.check_date <= td)
        except ValueError:
            pass

    check_ins = q.order_by(models.ActionCheckIn.check_date.asc()).all()
    return {
        "success": True,
        "committed_action": _serialize_action(action),
        "check_ins": [_serialize_check_in(c) for c in check_ins],
    }


# ── 헬퍼 ──

def _serialize_action(a: models.UserCommittedAction) -> dict:
    return {
        "id": a.id,
        "lifestyle_id": a.lifestyle_id,
        "section_key": a.section_key,
        "action_title": a.action_title,
        "action_detail": a.action_detail,
        "committed_at": a.committed_at.isoformat() if a.committed_at else None,
        "status": a.status,
    }


def _serialize_check_in(c: models.ActionCheckIn) -> dict:
    return {
        "id": c.id,
        "committed_action_id": c.committed_action_id,
        "check_date": c.check_date.isoformat(),
        "completed": c.completed,
        "note": c.note,
    }
