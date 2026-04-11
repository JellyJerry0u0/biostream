from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo
import logging
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Header, Query
from pydantic import AliasChoices, BaseModel, Field, ConfigDict
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models import HealthData, User, DailyLifestyleSnapshot, Lifestyle
from app.auth.security import verify_token

router = APIRouter(prefix="/api/v1", tags=["Health Sync"])
logger = logging.getLogger(__name__)

_KST = ZoneInfo("Asia/Seoul")


def _korea_today() -> date:
    """도커(UTC) 등에서 date.today()와 기기 달력이 하루 어긋날 때, 코치 트리거 등 보조용."""
    return datetime.now(_KST).date()


class HealthSyncRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    date: str
    steps: int = Field(ge=0)
    sleep_minutes: int = Field(alias="sleepMinutes", ge=0)
    distance_meters: float = Field(default=0.0, alias="distanceMeters", ge=0)
    oxygen_saturation: float = Field(default=0.0, alias="oxygenSaturation", ge=0)
    average_speed_mps: float = Field(default=0.0, alias="averageSpeedMps", ge=0)
    active_calories_kcal: float = Field(
        default=0.0,
        alias="activeCaloriesKcal",
        validation_alias=AliasChoices("activeCaloriesKcal", "nutritionCaloriesKcal"),
        ge=0,
    )
    exercise_minutes: int = Field(default=0, alias="exerciseMinutes", ge=0)
    fitness_score: float = Field(default=0.0, alias="fitnessScore", ge=0)
    weight_kg: float = Field(default=0.0, alias="weightKg", ge=0)
    height_cm: float = Field(default=0.0, alias="heightCm", ge=0)
    body_fat_percentage: float = Field(default=0.0, alias="bodyFatPercentage", ge=0)
    vo2_max: float = Field(default=0.0, alias="vo2Max", ge=0)
    blood_glucose_mg_dl: float = Field(default=0.0, alias="bloodGlucoseMgDl", ge=0)
    user_id: Optional[int] = Field(default=None, alias="userId")


class OutdoorCheckResponseRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    date: str
    answer: str = Field(pattern="^(yes|no|unknown)$")
    steps_snapshot: int = Field(default=0, alias="stepsSnapshot", ge=0)


def get_current_user(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
) -> User:
    if not authorization:
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")

    token = authorization.replace("Bearer ", "")
    email = verify_token(token)
    if not email:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="사용자를 찾을 수 없습니다.")

    return user


def _create_empty_daily_record(*, user_id: int, sync_date: date) -> HealthData:
    return HealthData(
        user_id=user_id,
        steps=0,
        sleep_minutes=0,
        distance_meters=0.0,
        oxygen_saturation=0.0,
        average_speed_mps=0.0,
        active_calories_kcal=0.0,
        exercise_minutes=0,
        fitness_score=0.0,
        weight_kg=0.0,
        height_cm=0.0,
        body_fat_percentage=0.0,
        vo2_max=0.0,
        blood_glucose_mg_dl=0.0,
        sync_date=sync_date,
        is_processed=False,
        notification_sent=False,
    )


def _compute_uv_exposure_score(record: HealthData) -> float:
    """yes/no/unknown 누적 응답 기반으로 0~100 UV 노출 점수를 계산합니다."""
    yes_points = record.outdoor_yes_count * 34.0
    unknown_points = record.outdoor_unknown_count * 8.0
    no_penalty = record.outdoor_no_count * 4.0
    score = max(0.0, min(100.0, yes_points + unknown_points - no_penalty))
    return round(score, 1)


def _serialize_health_record(record: HealthData) -> dict:
    return {
        "date": record.sync_date.isoformat(),
        "steps": record.steps,
        "sleepMinutes": record.sleep_minutes,
        "distanceMeters": record.distance_meters,
        "oxygenSaturation": record.oxygen_saturation,
        "averageSpeedMps": record.average_speed_mps,
        "activeCaloriesKcal": record.active_calories_kcal,
        "nutritionCaloriesKcal": record.active_calories_kcal,
        "exerciseMinutes": record.exercise_minutes,
        "fitnessScore": record.fitness_score,
        "weightKg": record.weight_kg,
        "heightCm": record.height_cm,
        "bodyFatPercentage": record.body_fat_percentage,
        "vo2Max": record.vo2_max,
        "bloodGlucoseMgDl": record.blood_glucose_mg_dl,
        "uvPromptCount": record.outdoor_prompt_count,
        "uvOutdoorYesCount": record.outdoor_yes_count,
        "uvOutdoorNoCount": record.outdoor_no_count,
        "uvOutdoorUnknownCount": record.outdoor_unknown_count,
        "uvExposureScore": record.uv_exposure_score,
        "uvSource": record.uv_source,
    }


@router.post("/sync-health")
async def sync_health_data(
    req: HealthSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    effective_user_id = current_user.id

    logger.info(
        "sync-health payload received: %s",
        {
            **req.model_dump(by_alias=True),
            "resolvedUserId": effective_user_id,
        },
    )

    try:
        sync_date = date.fromisoformat(req.date)
    except ValueError:
        raise HTTPException(status_code=422, detail="date must be ISO format YYYY-MM-DD")

    existing_data = db.query(HealthData).filter(
        HealthData.user_id == effective_user_id,
        HealthData.sync_date == sync_date
    ).first()

    if existing_data:
        existing_data.steps = req.steps
        existing_data.sleep_minutes = req.sleep_minutes
        existing_data.distance_meters = req.distance_meters
        existing_data.oxygen_saturation = req.oxygen_saturation
        existing_data.average_speed_mps = req.average_speed_mps
        existing_data.active_calories_kcal = req.active_calories_kcal
        existing_data.exercise_minutes = req.exercise_minutes
        existing_data.fitness_score = req.fitness_score
        existing_data.weight_kg = req.weight_kg
        existing_data.height_cm = req.height_cm
        existing_data.body_fat_percentage = req.body_fat_percentage
        existing_data.vo2_max = req.vo2_max
        existing_data.blood_glucose_mg_dl = req.blood_glucose_mg_dl
        existing_data.is_processed = False
        existing_data.notification_sent = False
    else:
        new_data = HealthData(
            user_id=effective_user_id,
            steps=req.steps,
            sleep_minutes=req.sleep_minutes,
            distance_meters=req.distance_meters,
            oxygen_saturation=req.oxygen_saturation,
            average_speed_mps=req.average_speed_mps,
            active_calories_kcal=req.active_calories_kcal,
            exercise_minutes=req.exercise_minutes,
            fitness_score=req.fitness_score,
            weight_kg=req.weight_kg,
            height_cm=req.height_cm,
            body_fat_percentage=req.body_fat_percentage,
            vo2_max=req.vo2_max,
            blood_glucose_mg_dl=req.blood_glucose_mg_dl,
            sync_date=sync_date,
            is_processed=False,
            notification_sent=False,
        )
        db.add(new_data)

    db.commit()
    return {"status": "success", "message": f"{req.date} 데이터 동기화 완료"}


@router.get("/recent-health-summary")
async def get_recent_health_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    days: int = 7,
):
    """최근 N일간 건강 데이터 집계 (운동 설문 자동채우기용)."""
    if days < 1 or days > 31:
        days = 7
    start_date = date.today() - timedelta(days=days)
    records = (
        db.query(HealthData)
        .filter(
            HealthData.user_id == current_user.id,
            HealthData.sync_date >= start_date,
        )
        .all()
    )
    total_exercise_minutes = sum(r.exercise_minutes or 0 for r in records)
    total_sleep_minutes = sum(r.sleep_minutes or 0 for r in records)
    return {
        "days": days,
        "recordCount": len(records),
        "exerciseMinutes": total_exercise_minutes,
        "sleepMinutes": total_sleep_minutes,
    }


@router.get("/yesterday-health")
async def get_yesterday_health_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    yesterday = date.today() - timedelta(days=1)
    record = (
        db.query(HealthData)
        .filter(
            HealthData.user_id == current_user.id,
            HealthData.sync_date == yesterday,
        )
        .first()
    )

    if not record:
        raise HTTPException(status_code=404, detail="어제 동기화된 건강 데이터가 없습니다.")

    return _serialize_health_record(record)


@router.get("/today-health")
async def get_today_health_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    record = (
        db.query(HealthData)
        .filter(
            HealthData.user_id == current_user.id,
            HealthData.sync_date == today,
        )
        .first()
    )

    if not record:
        raise HTTPException(status_code=404, detail="오늘 동기화된 건강 데이터가 없습니다.")

    return _serialize_health_record(record)


@router.post("/outdoor-check-response")
async def submit_outdoor_check_response(
    req: OutdoorCheckResponseRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        target_date = date.fromisoformat(req.date)
    except ValueError:
        raise HTTPException(status_code=422, detail="date must be ISO format YYYY-MM-DD")

    record = (
        db.query(HealthData)
        .filter(
            HealthData.user_id == current_user.id,
            HealthData.sync_date == target_date,
        )
        .first()
    )

    if not record:
        record = _create_empty_daily_record(user_id=current_user.id, sync_date=target_date)
        db.add(record)
        db.flush()

    if req.steps_snapshot > record.steps:
        record.steps = req.steps_snapshot

    record.outdoor_prompt_count += 1
    answer = req.answer.lower().strip()
    if answer == "yes":
        record.outdoor_yes_count += 1
    elif answer == "no":
        record.outdoor_no_count += 1
    else:
        record.outdoor_unknown_count += 1

    record.uv_source = "self_reported_step_prompt"
    record.uv_exposure_score = _compute_uv_exposure_score(record)
    record.updated_at = datetime.utcnow()
    db.commit()

    return {
        "success": True,
        "message": "야외 활동 응답이 저장되었습니다.",
        "date": record.sync_date.isoformat(),
        "uvPromptCount": record.outdoor_prompt_count,
        "uvOutdoorYesCount": record.outdoor_yes_count,
        "uvOutdoorNoCount": record.outdoor_no_count,
        "uvOutdoorUnknownCount": record.outdoor_unknown_count,
        "uvExposureScore": record.uv_exposure_score,
        "uvSource": record.uv_source,
    }


# ─── 오늘의 나의 생활 (Daily Lifestyle Snapshot) ───


class DailyLifestyleSnapshotBody(BaseModel):
    """오늘의 나의 생활 스냅샷 저장"""
    model_config = ConfigDict(populate_by_name=True)

    date: str = Field(..., description="YYYY-MM-DD")
    weight_kg: Optional[float] = Field(None, alias="weightKg", ge=0)
    height_cm: Optional[float] = Field(None, alias="heightCm", ge=0)
    drinking_days_per_week: Optional[str] = Field(None, alias="drinkingDaysPerWeek")
    smoking_status: Optional[str] = Field(None, alias="smokingStatus")
    stress_score: Optional[float] = Field(None, alias="stressScore", ge=0, le=10)
    sleep_minutes: Optional[int] = Field(None, alias="sleepMinutes", ge=0)
    sleep_quality_score: Optional[float] = Field(None, alias="sleepQualityScore", ge=0, le=10)
    aerobic_sessions_30min: Optional[int] = Field(None, alias="aerobicSessions30min", ge=0)
    resistance_sessions_30min: Optional[int] = Field(None, alias="resistanceSessions30min", ge=0)
    uv_outdoor_10to16: Optional[str] = Field(None, alias="uvOutdoor10to16")
    sunscreen_applied: Optional[bool] = Field(None, alias="sunscreenApplied")


def _get_latest_lifestyle(user_id: int, db: Session) -> Optional[Lifestyle]:
    """가장 최근 lifestyle 조회"""
    return db.query(Lifestyle).filter(Lifestyle.user_id == user_id).order_by(Lifestyle.created_at.desc()).first()


def _first_not_none(*vals):
    for v in vals:
        if v is not None:
            return v
    return None


def _or_positive_numeric(*vals):
    """체중·키 등: 양수만 채택."""
    for v in vals:
        if v is None:
            continue
        if isinstance(v, (int, float)) and v <= 0:
            continue
        return v
    return None


def _snapshot_row_complete(
    snapshot: Optional[DailyLifestyleSnapshot],
    health_record: Optional[HealthData] = None,
) -> bool:
    """오늘의 나 8영역 완료 여부. 수면은 스냅샷 또는 당일 health_data(동기화) 중 하나면 인정."""
    if snapshot is None:
        return False
    d = snapshot.drinking_days_per_week
    if d is None or not str(d).strip():
        return False
    sm = snapshot.smoking_status
    if sm is None or not str(sm).strip():
        return False
    if snapshot.stress_score is None:
        return False
    if snapshot.sleep_quality_score is None:
        return False
    uv = snapshot.uv_outdoor_10to16
    if uv is None or not str(uv).strip():
        return False
    if snapshot.sunscreen_applied is None:
        return False
    sleep_ok = (snapshot.sleep_minutes is not None and snapshot.sleep_minutes > 0) or (
        health_record is not None
        and health_record.sleep_minutes is not None
        and health_record.sleep_minutes > 0
    )
    if not sleep_ok:
        return False
    if snapshot.aerobic_sessions_30min is None or snapshot.resistance_sessions_30min is None:
        return False
    return True


@router.get("/today-lifestyle")
async def get_today_lifestyle(
    calendar_date: Optional[str] = Query(
        None,
        alias="date",
        description="기기 달력 기준 조회일 YYYY-MM-DD. 생략 시 서버 로컬 달력 오늘.",
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """오늘의 나: ChronoLens health_data 동기화 + 오늘 daily_snapshot + 설문은 체중·키만."""
    if calendar_date:
        try:
            today = date.fromisoformat(calendar_date)
        except ValueError:
            raise HTTPException(status_code=422, detail="date must be YYYY-MM-DD")
    else:
        today = date.today()

    health_record = db.query(HealthData).filter(
        HealthData.user_id == current_user.id,
        HealthData.sync_date == today,
    ).first()

    snapshot = db.query(DailyLifestyleSnapshot).filter(
        DailyLifestyleSnapshot.user_id == current_user.id,
        DailyLifestyleSnapshot.snapshot_date == today,
    ).first()

    lifestyle = _get_latest_lifestyle(current_user.id, db)

    sleep_minutes = _first_not_none(
        snapshot.sleep_minutes if snapshot else None,
        health_record.sleep_minutes if health_record else None,
    )

    return {
        "date": today.isoformat(),
        "hasDailySnapshot": snapshot is not None,
        "snapshotComplete": _snapshot_row_complete(snapshot, health_record),
        # 체중·키만 설문 (리포트 BMI와 동일 출처)
        "weightKg": _or_positive_numeric(lifestyle.weight if lifestyle else None),
        "heightCm": _or_positive_numeric(lifestyle.height if lifestyle else None),
        # 음주·흡연·스트레스·수면의질·UV·선크림·운동: 오늘 스냅샷만 (설문/유저 프로필 미병합)
        "drinkingDaysPerWeek": snapshot.drinking_days_per_week if snapshot else None,
        "smokingStatus": snapshot.smoking_status if snapshot else None,
        "stressScore": snapshot.stress_score if snapshot else None,
        # 수면(분): 오늘 스냅샷 → 동기화된 health_data (앱은 기기 건강 우선 병합)
        "sleepMinutes": sleep_minutes,
        "sleepQualityScore": snapshot.sleep_quality_score if snapshot else None,
        "aerobicSessions30min": snapshot.aerobic_sessions_30min if snapshot else None,
        "resistanceSessions30min": snapshot.resistance_sessions_30min if snapshot else None,
        "uvOutdoor10to16": snapshot.uv_outdoor_10to16 if snapshot else None,
        "sunscreenApplied": snapshot.sunscreen_applied if snapshot else None,
    }


@router.get("/daily-lifestyle-history")
async def get_daily_lifestyle_history(
    days: int = Query(14, ge=1, le=90, description="조회할 일수 (오늘 포함)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """일별 생활 스냅샷 시계열 (오늘의 나 그래프용)"""
    end = date.today()
    start = end - timedelta(days=days - 1)
    rows = (
        db.query(DailyLifestyleSnapshot)
        .filter(
            DailyLifestyleSnapshot.user_id == current_user.id,
            DailyLifestyleSnapshot.snapshot_date >= start,
            DailyLifestyleSnapshot.snapshot_date <= end,
        )
        .order_by(DailyLifestyleSnapshot.snapshot_date.asc())
        .all()
    )
    items = []
    for r in rows:
        items.append(
            {
                "date": r.snapshot_date.isoformat(),
                "weightKg": r.weight_kg,
                "heightCm": r.height_cm,
                "drinkingDaysPerWeek": r.drinking_days_per_week,
                "smokingStatus": r.smoking_status,
                "stressScore": r.stress_score,
                "sleepMinutes": r.sleep_minutes,
                "sleepQualityScore": r.sleep_quality_score,
                "aerobicSessions30min": r.aerobic_sessions_30min,
                "resistanceSessions30min": r.resistance_sessions_30min,
                "uvOutdoor10to16": r.uv_outdoor_10to16,
                "sunscreenApplied": r.sunscreen_applied,
            }
        )
    return {
        "days": days,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "items": items,
    }


@router.post("/daily-lifestyle-snapshot")
async def save_daily_lifestyle_snapshot(
    req: DailyLifestyleSnapshotBody,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """오늘의 나의 생활 스냅샷 저장 (자정 자동 저장용)"""
    try:
        target_date = date.fromisoformat(req.date)
    except ValueError:
        raise HTTPException(status_code=422, detail="date must be YYYY-MM-DD")

    existing = db.query(DailyLifestyleSnapshot).filter(
        DailyLifestyleSnapshot.user_id == current_user.id,
        DailyLifestyleSnapshot.snapshot_date == target_date,
    ).first()

    first_daily_snapshot_today = False

    if existing:
        # 스냅샷에 체중·키는 저장하지 않음(설문 전용). 요청에 있어도 무시.
        if req.drinking_days_per_week is not None:
            existing.drinking_days_per_week = req.drinking_days_per_week
        if req.smoking_status is not None:
            existing.smoking_status = req.smoking_status
        if req.stress_score is not None:
            existing.stress_score = req.stress_score
        if req.sleep_minutes is not None:
            existing.sleep_minutes = req.sleep_minutes
        if req.sleep_quality_score is not None:
            existing.sleep_quality_score = req.sleep_quality_score
        if req.aerobic_sessions_30min is not None:
            existing.aerobic_sessions_30min = req.aerobic_sessions_30min
        if req.resistance_sessions_30min is not None:
            existing.resistance_sessions_30min = req.resistance_sessions_30min
        if req.uv_outdoor_10to16 is not None:
            existing.uv_outdoor_10to16 = req.uv_outdoor_10to16
        if req.sunscreen_applied is not None:
            existing.sunscreen_applied = req.sunscreen_applied
    else:
        # POST의 date는 앱 기기 달력; 서버가 UTC면 date.today()와 하루 차이 날 수 있음
        if target_date == _korea_today():
            first_daily_snapshot_today = True
        snapshot = DailyLifestyleSnapshot(
            user_id=current_user.id,
            snapshot_date=target_date,
            weight_kg=None,
            height_cm=None,
            drinking_days_per_week=req.drinking_days_per_week,
            smoking_status=req.smoking_status,
            stress_score=req.stress_score,
            sleep_minutes=req.sleep_minutes,
            sleep_quality_score=req.sleep_quality_score,
            aerobic_sessions_30min=req.aerobic_sessions_30min,
            resistance_sessions_30min=req.resistance_sessions_30min,
            uv_outdoor_10to16=req.uv_outdoor_10to16,
            sunscreen_applied=req.sunscreen_applied,
        )
        db.add(snapshot)

    db.commit()

    if first_daily_snapshot_today:
        from app.services.coach_snapshot_nudge import run_snapshot_coach_nudge_for_user

        background_tasks.add_task(run_snapshot_coach_nudge_for_user, current_user.id)

    out: dict = {"success": True, "message": f"{req.date} 스냅샷이 저장되었습니다."}
    if first_daily_snapshot_today:
        out["first_daily_snapshot_today"] = True
    return out
