from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models import HealthData

router = APIRouter(prefix="/api/v1", tags=["Health Sync"])


class HealthSyncRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    date: str
    steps: int = Field(ge=0)
    sleep_minutes: int = Field(alias="sleepMinutes", ge=0)
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
        existing_data.is_processed = False
    else:
        new_data = HealthData(
            user_id=effective_user_id,
            steps=req.steps,
            sleep_minutes=req.sleep_minutes,
            sync_date=sync_date,
            is_processed=False
        )
        db.add(new_data)

    db.commit()
    return {"status": "success", "message": f"{req.date} 데이터 동기화 완료"}
