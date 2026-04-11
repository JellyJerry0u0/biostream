"""
설문 데이터 조회 도구
DB에서 사용자의 설문 데이터를 조회합니다.
"""

from typing import Dict, Any, Optional
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Lifestyle, User


def _lifestyle_to_dict(lifestyle: Lifestyle) -> Dict[str, Any]:
    """Lifestyle 객체를 딕셔너리로 변환하는 헬퍼 함수"""
    return {
        "user_id": lifestyle.user_id,
        "lifestyle_id": lifestyle.id,
        "outcomes": lifestyle.outcomes or [],
        "sleep_hours_weekday": lifestyle.sleep_hours_weekday,
        "sleep_hours_weekend": lifestyle.sleep_hours_weekend,
        "sleep_quality_score": lifestyle.sleep_quality_score,
        "uv_exposure_10to16": lifestyle.uv_exposure_10to16,
        "sunscreen_frequency": lifestyle.sunscreen_frequency,
        "sunscreen_reapply": lifestyle.sunscreen_reapply,
        "outdoor_sports_uv": lifestyle.outdoor_sports_uv,
        "drinking_days_per_week": lifestyle.drinking_days_per_week,
        "drinking_amount_per_session": lifestyle.drinking_amount_per_session,
        "smoking_status": lifestyle.smoking_status,
        "smoking_amount_per_day": lifestyle.smoking_amount_per_day,
        "smoking_days_per_week": lifestyle.smoking_days_per_week,
        "stress_score": lifestyle.stress_score,
        "aerobic_weekly": lifestyle.aerobic_weekly,
        "resistance_weekly": lifestyle.resistance_weekly,
        "height": lifestyle.height,
        "weight": lifestyle.weight,
        "skin_type": lifestyle.skin_type,
        "skin_satisfaction": lifestyle.skin_satisfaction,
        "target_years": lifestyle.target_years if lifestyle.target_years is not None else 30,
        "created_at": lifestyle.created_at.isoformat() if lifestyle.created_at else None
    }


def get_lifestyle(lifestyle_id: int, db: Optional[Session] = None) -> Dict[str, Any]:
    """
    lifestyle_id로 특정 설문 데이터를 조회합니다.
    
    Args:
        lifestyle_id: Lifestyle 레코드 ID
        db: 데이터베이스 세션 (None이면 자동으로 생성)
    
    Returns:
        설문 데이터 딕셔너리
    """
    if db is None:
        db_gen = get_db()
        db = next(db_gen)
        should_close = True
    else:
        should_close = False
    
    try:
        lifestyle = db.query(Lifestyle).filter(Lifestyle.id == lifestyle_id).first()
        
        if not lifestyle:
            return {
                "error": f"lifestyle_id={lifestyle_id}에 해당하는 설문 데이터를 찾을 수 없습니다.",
                "lifestyle_id": lifestyle_id
            }
        
        return _lifestyle_to_dict(lifestyle)
        
    except Exception as e:
        return {
            "error": f"설문 데이터 조회 실패: {str(e)}",
            "lifestyle_id": lifestyle_id
        }
    finally:
        if should_close:
            db.close()


def get_survey(user_id: int, lifestyle_id: Optional[int] = None, db: Optional[Session] = None) -> Dict[str, Any]:
    """
    사용자의 설문 데이터를 조회합니다.
    
    Args:
        user_id: 사용자 ID
        lifestyle_id: 특정 Lifestyle 레코드 ID (지정하면 해당 레코드 조회, None이면 최신 레코드)
        db: 데이터베이스 세션 (None이면 자동으로 생성)
    
    Returns:
        설문 데이터 딕셔너리
    """
    # lifestyle_id가 지정되면 해당 레코드 조회
    if lifestyle_id is not None:
        return get_lifestyle(lifestyle_id, db)
    
    # 그렇지 않으면 최신 레코드 조회
    if db is None:
        db_gen = get_db()
        db = next(db_gen)
        should_close = True
    else:
        should_close = False
    
    try:
        # 최신 Lifestyle 레코드 조회
        lifestyle = db.query(Lifestyle).filter(
            Lifestyle.user_id == user_id
        ).order_by(Lifestyle.created_at.desc()).first()
        
        if not lifestyle:
            return {
                "error": "설문 데이터를 찾을 수 없습니다.",
                "user_id": user_id
            }
        
        return _lifestyle_to_dict(lifestyle)
        
    except Exception as e:
        return {
            "error": f"설문 데이터 조회 실패: {str(e)}",
            "user_id": user_id
        }
    finally:
        if should_close:
            db.close()