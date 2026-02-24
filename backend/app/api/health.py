from datetime import date
import logging
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models import HealthData

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
    body_fat_percentage: float = Field(default=0.0, alias="bodyFatPercentage", ge=0)
    vo2_max: float = Field(default=0.0, alias="vo2Max", ge=0)
    blood_glucose_mg_dl: float = Field(default=0.0, alias="bloodGlucoseMgDl", ge=0)
    user_id: Optional[int] = Field(default=None, alias="userId")


@router.post("/sync-health")
async def sync_health_data(
    req: HealthSyncRequest,
    user_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    effective_user_id = user_id or req.user_id
    if effective_user_id is None:
        raise HTTPException(status_code=422, detail="user_id is required")

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
        existing_data.body_fat_percentage = req.body_fat_percentage
        existing_data.vo2_max = req.vo2_max
        existing_data.blood_glucose_mg_dl = req.blood_glucose_mg_dl
        existing_data.is_processed = False
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
            body_fat_percentage=req.body_fat_percentage,
            vo2_max=req.vo2_max,
            blood_glucose_mg_dl=req.blood_glucose_mg_dl,
            sync_date=sync_date,
            is_processed=False
        )
        db.add(new_data)

    db.commit()
    return {"status": "success", "message": f"{req.date} 데이터 동기화 완료"}
