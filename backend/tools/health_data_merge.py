"""
리포트용 설문 dict — 일별 스냅샷 병합 이후, 같은 7일 구간의 HealthData로
'비어 있는' 지표만 보완한다.

HealthData에 없는 항목(스트레스·음주·수면의 질·근력 구분 등)은 건드리지 않음.
"""

from __future__ import annotations

from datetime import date, timedelta
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import HealthData

from tools.daily_lifestyle_merge import _map_aerobic_weekly


def _positive_number(v: Any) -> bool:
    return v is not None and isinstance(v, (int, float)) and v > 0


def _sleep_hours_empty(v: Any) -> bool:
    return v is None


def _weekly_str_empty(v: Any) -> bool:
    return v is None or (isinstance(v, str) and not v.strip())


def _uv_bucket_from_score(avg: float) -> str:
    """ChronoLens UV 노출 점수(0~100) 평균 → 설문과 동일한 야외 시간대 라벨."""
    if avg < 22:
        return "<30m"
    if avg < 48:
        return "30~60"
    if avg < 72:
        return "1~2h"
    return ">2h"


def _infer_aerobic_sessions_for_day(r: HealthData) -> int:
    """앱 ExerciseAutoFillService와 유사: 운동 분·걸음·거리로 당일 30분+ 유산소 세션 수 추정."""
    ex = int(r.exercise_minutes or 0)
    st = int(r.steps or 0)
    dm = float(r.distance_meters or 0.0)
    if ex >= 30:
        return min(100, ex // 30)
    steps_sess = st // 5000
    dist_sess = int(dm // 2000) if dm > 0 else 0
    day_sess = max(steps_sess, dist_sess)
    if day_sess == 0 and (st >= 2000 or dm >= 800):
        return 1
    return min(day_sess, 100)


def fetch_health_rows_last_days(
    user_id: int,
    *,
    end: date,
    days: int = 7,
    db: Optional[Session] = None,
) -> List[HealthData]:
    start = end - timedelta(days=days - 1)
    own = db is None
    if own:
        db = SessionLocal()
    try:
        return (
            db.query(HealthData)
            .filter(
                HealthData.user_id == user_id,
                HealthData.sync_date >= start,
                HealthData.sync_date <= end,
            )
            .order_by(HealthData.sync_date.asc())
            .all()
        )
    finally:
        if own and db is not None:
            db.close()


def merge_health_data_fill_survey_gaps(
    survey: Dict[str, Any],
    user_id: int,
    *,
    as_of: Optional[date] = None,
    days: int = 7,
) -> Dict[str, Any]:
    """
    `merge_last_week_daily_lifestyle_into_survey` 이후의 dict를 입력으로 받는다.
    스냅샷·설문 어느 쪽에서도 채워지지 않은 숫자/활동 필드만 HealthData로 보완.
    """
    end = as_of or date.today()
    rows = fetch_health_rows_last_days(user_id, end=end, days=days)
    out = dict(survey)

    if not rows:
        return out

    filled: List[str] = []

    # 체중·키: HealthData로 설문 빈칸을 채우지 않음(설문 전용)

    # 수면(분) → 평일/주말 시간 (스냅샷·설문에서 비어 있는 쪽만)
    wd_mins: List[int] = []
    we_mins: List[int] = []
    for r in rows:
        sm = int(r.sleep_minutes or 0)
        if sm <= 0:
            continue
        if r.sync_date.weekday() < 5:
            wd_mins.append(sm)
        else:
            we_mins.append(sm)

    if _sleep_hours_empty(out.get("sleep_hours_weekday")) and wd_mins:
        out["sleep_hours_weekday"] = round(sum(wd_mins) / len(wd_mins) / 60.0, 2)
        filled.append("sleep_hours_weekday")
    if _sleep_hours_empty(out.get("sleep_hours_weekend")) and we_mins:
        out["sleep_hours_weekend"] = round(sum(we_mins) / len(we_mins) / 60.0, 2)
        filled.append("sleep_hours_weekend")

    if _sleep_hours_empty(out.get("sleep_hours_weekend")) and not we_mins and _positive_number(
        out.get("sleep_hours_weekday")
    ):
        out["sleep_hours_weekend"] = out["sleep_hours_weekday"]
        filled.append("sleep_hours_weekend(mirror)")
    if _sleep_hours_empty(out.get("sleep_hours_weekday")) and not wd_mins and _positive_number(
        out.get("sleep_hours_weekend")
    ):
        out["sleep_hours_weekday"] = out["sleep_hours_weekend"]
        filled.append("sleep_hours_weekday(mirror)")

    # 유산소(주간): 스냅샷이 aerobic_weekly를 주지 않은 경우에만 합산 추정
    if _weekly_str_empty(out.get("aerobic_weekly")):
        total_sess = sum(_infer_aerobic_sessions_for_day(r) for r in rows)
        if total_sess > 0:
            out["aerobic_weekly"] = _map_aerobic_weekly(total_sess)
            filled.append("aerobic_weekly")

    # 코어시간 외출: 스냅샷·설문에 없고, 동기화된 UV 점수만 있는 경우
    if not out.get("uv_exposure_10to16"):
        uv_scores = [
            float(r.uv_exposure_score)
            for r in rows
            if r.uv_exposure_score is not None and float(r.uv_exposure_score) > 0
        ]
        if uv_scores:
            avg_uv = sum(uv_scores) / len(uv_scores)
            out["uv_exposure_10to16"] = _uv_bucket_from_score(avg_uv)
            filled.append("uv_exposure_10to16")

    if filled:
        print(
            f"[HealthDataMerge] user={user_id} window={end - timedelta(days=days - 1)}..{end} "
            f"rows={len(rows)} → 빈 필드 보완: {', '.join(filled)}"
        )

    return out
