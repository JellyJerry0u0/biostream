from datetime import date
git pufrom fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import HealthData

router = APIRouter(prefix="/api/v1", tags=["Health Sync"])


class HealthSyncRequest(BaseModel):
    date: str
    steps: int = Field(ge=0)
    sleep_minutes: int = Field(ge=0)


@router.post("/sync-health")
async def sync_health_data(
    req: HealthSyncRequest,
    user_id: int,
    db: Session = Depends(get_db)
):
    try:
        sync_date = date.fromisoformat(req.date)
    except ValueError:
        raise HTTPException(status_code=422, detail="date must be ISO format YYYY-MM-DD")

    existing_data = db.query(HealthData).filter(
        HealthData.user_id == user_id,
        HealthData.sync_date == sync_date
    ).first()

    if existing_data:
        existing_data.steps = req.steps
        existing_data.sleep_minutes = req.sleep_minutes
        existing_data.is_processed = False
    else:
        new_data = HealthData(
            user_id=user_id,
            steps=req.steps,
            sleep_minutes=req.sleep_minutes,
            sync_date=sync_date,
            is_processed=False
        )
        db.add(new_data)

    db.commit()
    return {"status": "success", "message": f"{req.date} 데이터 동기화 완료"}
