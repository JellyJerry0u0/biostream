"""
DB·세션에서 에이전트 컨텍스트를 적재한다.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple
import uuid

from sqlalchemy.orm import Session

from app.coach_agent.data_sources import SqlAlchemyHealthDataSource
from app.coach_agent.memory_store import SessionDictCoachMemoryStore, parse_persisted
from app.coach_agent.schemas import (
    AdaptiveGoal,
    GoalDomain,
    GoalStatus,
    HealthLog,
    UserProfile,
)


def _section_to_domain(section_key: str) -> GoalDomain:
    m = {
        "sleep": GoalDomain.sleep,
        "activity": GoalDomain.exercise,
        "uv": GoalDomain.uv_protection,
        "drinking": GoalDomain.alcohol,
        "smoking": GoalDomain.smoking,
        "stress": GoalDomain.stress,
        "goals": GoalDomain.skin_routine,
    }
    return m.get(section_key, GoalDomain.general)


async def load_user_context_bundle(
    user_id: int,
    db: Session,
    session: Any,
    report_ctx: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Returns dict with keys: profile, recent_health_logs, active_goals, goal_history,
    episodic_memory, coaching_memory, checkin_by_goal, conversation_history
    """
    from app.models import Lifestyle, User, UserCommittedAction, ActionCheckIn

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError(f"user not found: {user_id}")

    lifestyle: Optional[Lifestyle] = None
    rid = getattr(session, "report_id", None)
    if rid:
        lifestyle = (
            db.query(Lifestyle)
            .filter(Lifestyle.id == rid, Lifestyle.user_id == user_id)
            .first()
        )
    if not lifestyle:
        lifestyle = (
            db.query(Lifestyle)
            .filter(Lifestyle.user_id == user_id)
            .order_by(Lifestyle.created_at.desc())
            .first()
        )

    height_cm = None
    weight_kg = None
    if lifestyle:
        if lifestyle.height and lifestyle.height > 0:
            height_cm = float(lifestyle.height)
        if lifestyle.weight and lifestyle.weight > 0:
            weight_kg = float(lifestyle.weight)

    profile = UserProfile(
        user_id=user_id,
        nickname=user.nickname or "",
        birthdate=user.birthdate,
        gender=user.gender,
        smoking_status=user.smoking_status or (lifestyle.smoking_status if lifestyle else None),
        height_cm=height_cm,
        weight_kg=weight_kg,
        survey_sleep_weekday_h=lifestyle.sleep_hours_weekday if lifestyle else None,
        survey_sleep_weekend_h=lifestyle.sleep_hours_weekend if lifestyle else None,
        survey_stress_0_10=lifestyle.stress_score if lifestyle else None,
        survey_aerobic_bucket=lifestyle.aerobic_weekly if lifestyle else None,
        survey_drinking_days_per_week=lifestyle.drinking_days_per_week if lifestyle else None,
        survey_sunscreen_frequency=lifestyle.sunscreen_frequency if lifestyle else None,
        data_sources=["survey" if lifestyle else "user_table"],
    )

    src = SqlAlchemyHealthDataSource(db)
    health_logs = await src.fetch_recent_logs(user_id, days=30)
    if health_logs:
        profile.data_sources.append("health_data_table")

    store = SessionDictCoachMemoryStore(session)
    blob = store.load()
    persisted_goals, goal_history, episodic, coaching_memory = parse_persisted(blob)

    actions = (
        db.query(UserCommittedAction)
        .filter(
            UserCommittedAction.user_id == user_id,
            UserCommittedAction.status == "active",
        )
        .order_by(UserCommittedAction.committed_at.desc())
        .limit(12)
        .all()
    )

    today = date.today()
    from_date = today - timedelta(days=30)
    action_ids = [a.id for a in actions]
    checkin_by_goal: Dict[str, List[Tuple[date, bool]]] = {}
    check_ins = []
    if action_ids:
        check_ins = (
            db.query(ActionCheckIn)
            .filter(
                ActionCheckIn.committed_action_id.in_(action_ids),
                ActionCheckIn.check_date >= from_date,
                ActionCheckIn.check_date <= today,
            )
            .all()
        )

    by_action: Dict[int, List[Tuple[date, bool]]] = {}
    for c in check_ins:
        by_action.setdefault(c.committed_action_id, []).append((c.check_date, c.completed))

    committed_goals: List[AdaptiveGoal] = []
    for a in actions:
        gid = f"committed_{a.id}"
        checks = by_action.get(a.id, [])
        completed_7 = [d for d, ok in checks if ok and d >= today - timedelta(days=7)]
        total_7 = len([d for d, _ in checks if d >= today - timedelta(days=7)])
        rate = (len(completed_7) / total_7) if total_7 else 0.0
        committed_goals.append(
            AdaptiveGoal(
                goal_id=gid,
                domain=_section_to_domain(a.section_key),
                description=a.action_title,
                current_target=a.action_detail or a.action_title,
                unit=None,
                status=GoalStatus.active,
                confidence=0.65,
                success_rate_7d=rate,
                success_rate_30d=rate,
                last_updated_at=datetime.now(timezone.utc),
                revision_reason="리포트에서 선택한 실천 습관",
            )
        )
        checkin_by_goal[gid] = checks

    # persisted goals override same goal_id
    gid_seen = {g.goal_id for g in persisted_goals}
    merged = list(persisted_goals)
    for cg in committed_goals:
        if cg.goal_id not in gid_seen:
            merged.append(cg)
            gid_seen.add(cg.goal_id)

    if not merged:
        merged = _default_seed_goals_from_survey(lifestyle, user_id)

    conv = session.get_history_for_prompt() if hasattr(session, "get_history_for_prompt") else []

    return {
        "profile": profile,
        "recent_health_logs": [h.model_dump(mode="json") for h in health_logs],
        "active_goals": [g.model_dump(mode="json") for g in merged],
        "goal_history": [h.model_dump(mode="json") for h in goal_history],
        "episodic_memory": [e.model_dump(mode="json") for e in episodic],
        "coaching_memory": coaching_memory.model_dump(mode="json"),
        "checkin_by_goal": checkin_by_goal,
        "conversation_history": conv,
        "_raw_goals": merged,
        "_raw_logs": health_logs,
    }


def _default_seed_goals_from_survey(
    lifestyle: Optional[Any],
    user_id: int,
) -> List[AdaptiveGoal]:
    """습관·목표 DB가 비었을 때 설문만으로 최소 시드."""
    if not lifestyle:
        return [
            AdaptiveGoal(
                goal_id=f"seed_general_{user_id}",
                domain=GoalDomain.general,
                description="매일 작은 피부·건강 습관 유지",
                current_target="하루 1가지 미세 습관 실천",
                status=GoalStatus.active,
                last_updated_at=datetime.now(timezone.utc),
            )
        ]
    goals: List[AdaptiveGoal] = []
    if lifestyle.sleep_hours_weekday and lifestyle.sleep_hours_weekday < 7:
        goals.append(
            AdaptiveGoal(
                goal_id=f"seed_sleep_{user_id}",
                domain=GoalDomain.sleep,
                description="평일 수면",
                current_target=f"평일 평균 {max(6.0, lifestyle.sleep_hours_weekday):.1f}시간 이상 지향 (단계적 개선)",
                unit="hours/night",
                status=GoalStatus.active,
                last_updated_at=datetime.now(timezone.utc),
            )
        )
    _low_sun = (
        "never",
        "sometimes",
        "0",
        "1",
        "2-3",
    )
    if lifestyle.sunscreen_frequency in _low_sun:
        goals.append(
            AdaptiveGoal(
                goal_id=f"seed_uv_{user_id}",
                domain=GoalDomain.uv_protection,
                description="자외선 차단",
                current_target="야외 전 선크림 바르기",
                status=GoalStatus.active,
                last_updated_at=datetime.now(timezone.utc),
            )
        )
    if not goals:
        goals.append(
            AdaptiveGoal(
                goal_id=f"seed_general_{user_id}",
                domain=GoalDomain.general,
                description="생활 리듬 관리",
                current_target="오늘 할 일 한 가지 정하기",
                status=GoalStatus.active,
                last_updated_at=datetime.now(timezone.utc),
            )
        )
    return goals
