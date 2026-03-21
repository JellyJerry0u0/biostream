from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Lifestyle

router = APIRouter()

@router.get("/skin-age-history/{user_id}")
def get_skin_age_history(user_id: int, db: Session = Depends(get_db)):

    lifestyles = (
        db.query(Lifestyle)
        .filter(Lifestyle.user_id == user_id)
        .order_by(Lifestyle.created_at.asc())
        .all()
    )

    history = []

    for l in lifestyles:
        if not l.health_report:
            continue

        history.append({
            "date": str(l.created_at.date()),
            "age": l.health_report.get("skin_age", 0)
        })

    return {"skin_age_history": history}