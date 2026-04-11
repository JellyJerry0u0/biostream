"""
외부 건강 데이터 소스 추상화.

추후 HealthKit / Health Connect 연동 시 이 인터페이스만 교체·합성하면 된다.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import date, timedelta
from typing import List, Optional
import uuid

from sqlalchemy.orm import Session

from app.coach_agent.schemas import GoalDomain, HealthLog


class HealthDataSource(ABC):
    """사용자별 최근 건강 로그 조회 (도메인 무관)."""

    @abstractmethod
    async def fetch_recent_logs(
        self,
        user_id: int,
        days: int = 30,
    ) -> List[HealthLog]:
        ...


class SqlAlchemyHealthDataSource(HealthDataSource):
    """
    현재 DB 스키마(HealthData, DailyLifestyleSnapshot)에서 로그를 구성한다.
    동기 DB를 async 인터페이스로 감싼 이유: 나중에 완전 비동기 소스와 동일 시그니처 유지.
    """

    def __init__(self, db: Session):
        self._db = db

    async def fetch_recent_logs(self, user_id: int, days: int = 30) -> List[HealthLog]:
        from app.models import DailyLifestyleSnapshot, HealthData

        end = date.today()
        start = end - timedelta(days=days)
        logs: List[HealthLog] = []

        rows = (
            self._db.query(HealthData)
            .filter(
                HealthData.user_id == user_id,
                HealthData.sync_date >= start,
                HealthData.sync_date <= end,
            )
            .order_by(HealthData.sync_date.desc())
            .limit(120)
            .all()
        )
        for r in rows:
            if r.sleep_minutes and r.sleep_minutes > 0:
                logs.append(
                    HealthLog(
                        log_id=f"hd_{r.id}_sleep",
                        user_id=user_id,
                        log_date=r.sync_date,
                        source="health_data",
                        domain=GoalDomain.sleep,
                        metric_key="sleep_minutes",
                        value_numeric=float(r.sleep_minutes),
                        unit="minutes",
                        raw={"steps": r.steps, "exercise_minutes": r.exercise_minutes},
                    )
                )
            if r.steps and r.steps > 0:
                logs.append(
                    HealthLog(
                        log_id=f"hd_{r.id}_steps",
                        user_id=user_id,
                        log_date=r.sync_date,
                        source="health_data",
                        domain=GoalDomain.exercise,
                        metric_key="steps",
                        value_numeric=float(r.steps),
                        unit="count",
                        raw={},
                    )
                )
            if r.exercise_minutes and r.exercise_minutes > 0:
                logs.append(
                    HealthLog(
                        log_id=f"hd_{r.id}_ex",
                        user_id=user_id,
                        log_date=r.sync_date,
                        source="health_data",
                        domain=GoalDomain.exercise,
                        metric_key="exercise_minutes",
                        value_numeric=float(r.exercise_minutes),
                        unit="minutes",
                        raw={},
                    )
                )
            yes = r.outdoor_yes_count or 0
            no = r.outdoor_no_count or 0
            if yes + no > 0:
                logs.append(
                    HealthLog(
                        log_id=f"hd_{r.id}_outdoor",
                        user_id=user_id,
                        log_date=r.sync_date,
                        source="health_data",
                        domain=GoalDomain.uv_protection,
                        metric_key="outdoor_yes_ratio",
                        value_numeric=yes / (yes + no),
                        unit="ratio",
                        raw={"yes": yes, "no": no},
                    )
                )

        snaps = (
            self._db.query(DailyLifestyleSnapshot)
            .filter(
                DailyLifestyleSnapshot.user_id == user_id,
                DailyLifestyleSnapshot.snapshot_date >= start,
                DailyLifestyleSnapshot.snapshot_date <= end,
            )
            .order_by(DailyLifestyleSnapshot.snapshot_date.desc())
            .limit(60)
            .all()
        )
        for s in snaps:
            if s.sleep_minutes is not None and s.sleep_minutes > 0:
                logs.append(
                    HealthLog(
                        log_id=f"dls_{s.id}_sleep",
                        user_id=user_id,
                        log_date=s.snapshot_date,
                        source="daily_snapshot",
                        domain=GoalDomain.sleep,
                        metric_key="sleep_minutes",
                        value_numeric=float(s.sleep_minutes),
                        unit="minutes",
                        raw={},
                    )
                )
            if s.stress_score is not None:
                logs.append(
                    HealthLog(
                        log_id=f"dls_{s.id}_stress",
                        user_id=user_id,
                        log_date=s.snapshot_date,
                        source="daily_snapshot",
                        domain=GoalDomain.stress,
                        metric_key="stress_score",
                        value_numeric=float(s.stress_score),
                        unit="0-10",
                        raw={},
                    )
                )

        logs.sort(key=lambda x: x.log_date, reverse=True)
        return logs


class MockHealthDataSource(HealthDataSource):
    """테스트·데모용."""

    def __init__(self, logs: Optional[List[HealthLog]] = None):
        self._logs = logs or []

    async def fetch_recent_logs(self, user_id: int, days: int = 30) -> List[HealthLog]:
        return [x for x in self._logs if x.user_id == user_id]


def new_episode_id() -> str:
    return str(uuid.uuid4())
