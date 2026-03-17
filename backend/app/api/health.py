from datetime import date, timedelta
import logging
from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models import HealthData, User
from app.auth.security import verify_token

router = APIRouter(prefix="/api/v1", tags=["Health Sync"])
logger = logging.getLogger(__name__)


class HealthSyncRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    date: str
    steps: int = Field(ge=0)
    sleep_minutes: int = Field(alias="sleepMinutes", ge=0)
    distance_meters: float = Field(default=0.0, alias="distanceMeters", ge=0)
    oxygen_saturation: float = Field(default=0.0, alias="oxygenSaturation", ge=0)
    average_speed_mps: float = Field(default=0.0, alias="averageSpeedMps", ge=0)
    nutrition_calories_kcal: float = Field(default=0.0, alias="nutritionCaloriesKcal", ge=0)
    exercise_minutes: int = Field(default=0, alias="exerciseMinutes", ge=0)
    fitness_score: float = Field(default=0.0, alias="fitnessScore", ge=0)
    weight_kg: float = Field(default=0.0, alias="weightKg", ge=0)
    height_cm: float = Field(default=0.0, alias="heightCm", ge=0)
    body_fat_percentage: float = Field(default=0.0, alias="bodyFatPercentage", ge=0)
    vo2_max: float = Field(default=0.0, alias="vo2Max", ge=0)
    blood_glucose_mg_dl: float = Field(default=0.0, alias="bloodGlucoseMgDl", ge=0)
    user_id: Optional[int] = Field(default=None, alias="userId")


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
        existing_data.nutrition_calories_kcal = req.nutrition_calories_kcal
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
            nutrition_calories_kcal=req.nutrition_calories_kcal,
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

    return {
        "date": record.sync_date.isoformat(),
        "steps": record.steps,
        "sleepMinutes": record.sleep_minutes,
        "distanceMeters": record.distance_meters,
        "oxygenSaturation": record.oxygen_saturation,
        "averageSpeedMps": record.average_speed_mps,
        "nutritionCaloriesKcal": record.nutrition_calories_kcal,
        "exerciseMinutes": record.exercise_minutes,
        "fitnessScore": record.fitness_score,
        "weightKg": record.weight_kg,
        "heightCm": record.height_cm,
        "bodyFatPercentage": record.body_fat_percentage,
        "vo2Max": record.vo2_max,
        "bloodGlucoseMgDl": record.blood_glucose_mg_dl,
    }
