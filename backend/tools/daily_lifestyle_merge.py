"""
리포트 생성 시 '오늘의 나의 생활' 일별 스냅샷(최근 7일)을 설문 dict에 병합.

- 스냅샷에 값이 있으면 해당 지표는 집계값으로 덮어씀
- 7일 내 해당 필드가 전혀 없으면 설문(Lifestyle) 기존 값 유지 (= 기존 동작)

이후 같은 7일 구간의 HealthData로 빈 필드만 보완하려면
`tools.health_data_merge.merge_health_data_fill_survey_gaps` 를 이어서 호출한다.
"""

from __future__ import annotations

from collections import Counter
from datetime import date, timedelta
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import DailyLifestyleSnapshot


def _map_aerobic_weekly(total_sessions: int) -> str:
    if total_sessions <= 0:
        return "0"
    if total_sessions <= 2:
        return "1-2"
    if total_sessions <= 4:
        return "3-4"
    return "5+"


def _map_resistance_weekly(total_sessions: int) -> str:
    if total_sessions <= 0:
        return "0"
    if total_sessions == 1:
        return "1"
    if total_sessions == 2:
        return "2"
    return "3+"


def _bucket_weekly_from_count(n: int) -> str:
    """주 0~7일을 설문 버킷(0/1/2-3/4-5/6-7)으로 매핑."""
    n = max(0, min(7, int(n)))
    if n == 0:
        return "0"
    if n == 1:
        return "1"
    if n <= 3:
        return "2-3"
    if n <= 5:
        return "4-5"
    return "6-7"


def fetch_snapshots_last_days(
    user_id: int,
    *,
    end: date,
    days: int = 7,
    db: Optional[Session] = None,
) -> List[DailyLifestyleSnapshot]:
    """end를 포함해 과거 days일(달력일) 구간의 스냅샷, 날짜 오름차순."""
    start = end - timedelta(days=days - 1)
    own_session = db is None
    if own_session:
        db = SessionLocal()
    try:
        q = (
            db.query(DailyLifestyleSnapshot)
            .filter(
                DailyLifestyleSnapshot.user_id == user_id,
                DailyLifestyleSnapshot.snapshot_date >= start,
                DailyLifestyleSnapshot.snapshot_date <= end,
            )
            .order_by(DailyLifestyleSnapshot.snapshot_date.asc())
        )
        return q.all()
    finally:
        if own_session and db is not None:
            db.close()


def merge_last_week_daily_lifestyle_into_survey(
    survey: Dict[str, Any],
    user_id: int,
    *,
    as_of: Optional[date] = None,
    days: int = 7,
) -> Dict[str, Any]:
    """
    설문 dict 복사본에 최근 `days`일 일별 생활 스냅샷 집계를 반영.

    outcomes, skin_type 등 설문 전용 필드는 건드리지 않음.
    """
    end = as_of or date.today()
    rows = fetch_snapshots_last_days(user_id, end=end, days=days)
    out = dict(survey)

    if not rows:
        return out

    # 체중·키는 일별 스냅샷에 두지 않음 — 리포트 BMI는 설문(Lifestyle) 값만 사용

    # 수면(분): 평일/주말 평균 → 시간
    wd_mins: List[int] = []
    we_mins: List[int] = []
    for r in rows:
        if r.sleep_minutes is None or r.sleep_minutes <= 0:
            continue
        if r.snapshot_date.weekday() < 5:
            wd_mins.append(r.sleep_minutes)
        else:
            we_mins.append(r.sleep_minutes)
    if wd_mins:
        out["sleep_hours_weekday"] = round(sum(wd_mins) / len(wd_mins) / 60.0, 2)
    if we_mins:
        out["sleep_hours_weekend"] = round(sum(we_mins) / len(we_mins) / 60.0, 2)
    if wd_mins and not we_mins:
        out["sleep_hours_weekend"] = out["sleep_hours_weekday"]
    if we_mins and not wd_mins:
        out["sleep_hours_weekday"] = out["sleep_hours_weekend"]

    # 수면의 질
    sq = [r.sleep_quality_score for r in rows if r.sleep_quality_score is not None]
    if sq:
        out["sleep_quality_score"] = round(sum(sq) / len(sq), 2)

    # 스트레스
    st = [r.stress_score for r in rows if r.stress_score is not None]
    if st:
        out["stress_score"] = round(sum(st) / len(st), 2)

    # 음주: 일별 0/1(금주·음주)이면 주간 추정 → 버킷, 아니면 기존처럼 최빈 라벨
    dr = [r.drinking_days_per_week for r in rows if r.drinking_days_per_week]
    if dr:
        dr_norm = [str(v).strip() for v in dr]
        if dr_norm and all(x in ("0", "1") for x in dr_norm):
            drank = sum(1 for x in dr_norm if x == "1")
            est = int(round(7 * drank / len(dr_norm)))
            out["drinking_days_per_week"] = _bucket_weekly_from_count(est)
        else:
            out["drinking_days_per_week"] = Counter(dr_norm).most_common(1)[0][0]

    # 흡연 상태: 최신 날짜 비어 있지 않은 값
    smoking_row: Optional[DailyLifestyleSnapshot] = None
    for r in rows:
        if r.smoking_status:
            if smoking_row is None or r.snapshot_date >= smoking_row.snapshot_date:
                smoking_row = r
    if smoking_row is not None:
        out["smoking_status"] = smoking_row.smoking_status

    # 주당 흡연일수: 일별 never/current만 있으면 비율로 주간 추정
    sm_days = [
        r.smoking_status
        for r in rows
        if r.smoking_status and str(r.smoking_status).strip().lower() in ("current", "never")
    ]
    if sm_days:
        smoked = sum(1 for s in sm_days if str(s).strip().lower() == "current")
        est = int(round(7 * smoked / len(sm_days)))
        out["smoking_days_per_week"] = _bucket_weekly_from_count(est)

    # 코어시간 외출
    uvs = [r.uv_outdoor_10to16 for r in rows if r.uv_outdoor_10to16]
    if uvs:
        out["uv_exposure_10to16"] = Counter(uvs).most_common(1)[0][0]

    # 선크림: 기록된 날 기준 도포 비율 → 주 N회 버킷(스냅샷과 동일 스케일)
    sun_days = [r.sunscreen_applied for r in rows if r.sunscreen_applied is not None]
    if sun_days:
        applied = sum(1 for x in sun_days if x)
        est = int(round(7 * applied / len(sun_days)))
        out["sunscreen_frequency"] = _bucket_weekly_from_count(est)

    # 운동: null이 아닌 날만 합산(주간 합으로 설문 버킷에 매핑)
    aer_vals = [r.aerobic_sessions_30min for r in rows if r.aerobic_sessions_30min is not None]
    if aer_vals:
        out["aerobic_weekly"] = _map_aerobic_weekly(sum(aer_vals))

    res_vals = [r.resistance_sessions_30min for r in rows if r.resistance_sessions_30min is not None]
    if res_vals:
        out["resistance_weekly"] = _map_resistance_weekly(sum(res_vals))

    print(
        f"[DailyLifestyleMerge] user={user_id} window={end - timedelta(days=days - 1)}..{end} "
        f"snapshots={len(rows)} → 설문 지표 병합 적용"
    )
    return out
