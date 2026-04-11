"""로컬 실행·단위 테스트용 목 데이터."""

from __future__ import annotations

from datetime import date, timedelta

from app.coach_agent.schemas import (
    AdaptiveGoal,
    GoalDomain,
    GoalStatus,
    HealthLog,
    UserProfile,
)


def sample_profile() -> UserProfile:
    return UserProfile(
        user_id=1,
        nickname="테스트",
        height_cm=170.0,
        weight_kg=72.0,
        survey_sleep_weekday_h=6.0,
        survey_stress_0_10=7.0,
        data_sources=["survey", "health_data_table"],
    )


def sample_logs(user_id: int = 1) -> list[HealthLog]:
    today = date.today()
    out: list[HealthLog] = []
    for i in range(7):
        d = today - timedelta(days=i)
        minutes = 330 + i * 15  # 점점 늦어짐
        out.append(
            HealthLog(
                log_id=f"m_{i}",
                user_id=user_id,
                log_date=d,
                source="health_data",
                domain=GoalDomain.sleep,
                metric_key="sleep_minutes",
                value_numeric=float(minutes),
                unit="minutes",
                raw={},
            )
        )
    return out


def sample_goals(user_id: int = 1) -> list[AdaptiveGoal]:
    return [
        AdaptiveGoal(
            goal_id="committed_1",
            domain=GoalDomain.sleep,
            description="평일 수면",
            current_target="평일 6.5시간 이상",
            unit="hours",
            status=GoalStatus.active,
            success_rate_7d=0.25,
        )
    ]
