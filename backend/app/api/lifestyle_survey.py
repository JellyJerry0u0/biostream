from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import Optional, List
from app.database import get_db
from app.models import User, Lifestyle
from app.auth.security import verify_token
from pydantic import BaseModel

router = APIRouter()

# 입력을 위한 데이터 모델 (새로운 설문 구조)
class LifestyleSurveyCreate(BaseModel):
    # A. 주요 목표 (리포트 톤 라우팅) - multi choice
    outcomes: Optional[List[str]] = None  # ["wrinkle", "elasticity", "pigmentation", "hydration", "hydration_barrier", "acne", "redness", "general_aging"]
    
    # B. Sleep & Rhythm (5)
    sleep_hours_weekday: Optional[float] = None  # 평균 수면시간(평일) 3~10h
    sleep_hours_weekend: Optional[float] = None  # 평균 수면시간(주말)
    sleep_quality_score: Optional[float] = None  # 수면의 질(주관) 0~10
    
    # C. UV / Photoaging (4)
    uv_exposure_10to16: Optional[str] = None  # 야외 노출(10~16시): <30m / 30~60 / 1~2h / >2h
    sunscreen_frequency: Optional[str] = None  # 선크림 주 N회: 0/1/2-3/4-5/6-7 (레거시 코드 호환)
    sunscreen_reapply: Optional[str] = None  # 재도포(2~3시간 간격): never/rarely/sometimes/often
    outdoor_sports_uv: Optional[str] = None  # 야외스포츠(강한 UV): none/monthly/weekly
    
    # D. Alcohol & Smoking (4)
    drinking_days_per_week: Optional[str] = None  # 주당 음주일수: 0 / 1 / 2-3 / 4-5 / 6-7
    drinking_amount_per_session: Optional[str] = None  # 레거시 (앱에서는 미전송)
    smoking_status: Optional[str] = None  # never/former/current
    smoking_amount_per_day: Optional[str] = None  # 레거시 (앱에서는 미전송)
    smoking_days_per_week: Optional[str] = None  # 주당 흡연일수: 0 / 1 / 2-3 / 4-5 / 6-7
    
    # E. Stress & Recovery
    stress_score: Optional[float] = None  # 스트레스(지난 2주) 0~10
    
    # F. Activity & Metabolic (3)
    aerobic_weekly: Optional[str] = None  # 유산소(주당): 0 / 1-2 / 3-4 / 5+
    resistance_weekly: Optional[str] = None  # 근력(주당): 0 / 1 / 2 / 3+
    height: Optional[float] = None  # 키
    weight: Optional[float] = None  # 몸무게
    
    # Skin 상태
    skin_type: Optional[str] = None  # 피부 타입: dry/oily/combination/sensitive
    skin_satisfaction: Optional[float] = None  # 현재 피부상태 만족도 0~10
    
    # 목표 연도 (고정값 30)
    target_years: Optional[int] = 30
    # 이미지 URL (기존 호환성)
    original_image_url: Optional[str] = None
    # /data/upload 로 만든 lifestyle 행에 설문만 채울 때 (없으면 기존처럼 새 행 INSERT)
    lifestyle_id: Optional[int] = None


def _apply_survey_payload_to_lifestyle(
    lifestyle: Lifestyle,
    profile_data: LifestyleSurveyCreate,
    *,
    update_original_image: bool,
) -> None:
    lifestyle.outcomes = profile_data.outcomes
    lifestyle.sleep_hours_weekday = profile_data.sleep_hours_weekday
    lifestyle.sleep_hours_weekend = profile_data.sleep_hours_weekend
    lifestyle.sleep_quality_score = profile_data.sleep_quality_score
    lifestyle.uv_exposure_10to16 = profile_data.uv_exposure_10to16
    lifestyle.sunscreen_frequency = profile_data.sunscreen_frequency
    lifestyle.sunscreen_reapply = profile_data.sunscreen_reapply
    lifestyle.outdoor_sports_uv = profile_data.outdoor_sports_uv
    lifestyle.drinking_days_per_week = profile_data.drinking_days_per_week
    lifestyle.drinking_amount_per_session = profile_data.drinking_amount_per_session
    lifestyle.smoking_status = profile_data.smoking_status
    lifestyle.smoking_amount_per_day = profile_data.smoking_amount_per_day
    lifestyle.smoking_days_per_week = profile_data.smoking_days_per_week
    lifestyle.stress_score = profile_data.stress_score
    lifestyle.aerobic_weekly = profile_data.aerobic_weekly
    lifestyle.resistance_weekly = profile_data.resistance_weekly
    lifestyle.height = profile_data.height
    lifestyle.weight = profile_data.weight
    lifestyle.skin_type = profile_data.skin_type
    lifestyle.skin_satisfaction = profile_data.skin_satisfaction
    lifestyle.target_years = (
        profile_data.target_years if profile_data.target_years is not None else 30
    )
    if update_original_image and profile_data.original_image_url is not None:
        lifestyle.original_image_url = profile_data.original_image_url


def get_current_user(authorization: Optional[str] = None, db: Session = Depends(get_db)):
    if not authorization:
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")
    
    try:
        token = authorization.replace("Bearer ", "")
        email = verify_token(token)
        if not email:
            raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
        
        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(status_code=401, detail="사용자를 찾을 수 없습니다.")
        
        return user
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"인증 실패: {str(e)}")

@router.post("/lifestyle-profile")
def create_lifestyle_profile(
    profile_data: LifestyleSurveyCreate,
    authorization: Optional[str] = Header(None, alias="Authorization"),
    db: Session = Depends(get_db)
):
    # 인증 확인
    current_user = get_current_user(authorization, db)

    if profile_data.lifestyle_id is not None:
        lifestyle = (
            db.query(Lifestyle)
            .filter(
                Lifestyle.id == profile_data.lifestyle_id,
                Lifestyle.user_id == current_user.id,
            )
            .first()
        )
        if not lifestyle:
            raise HTTPException(status_code=404, detail="Lifestyle not found")

        _apply_survey_payload_to_lifestyle(
            lifestyle,
            profile_data,
            update_original_image=True,
        )
        db.commit()
        db.refresh(lifestyle)

        print(
            f"✅ Lifestyle 레코드 갱신 완료 - lifestyle_id: {lifestyle.id}, user_id: {current_user.id}"
        )

        return {
            "success": True,
            "message": "생활습관 정보가 저장되었습니다.",
            "lifestyle_id": lifestyle.id,
            "user_id": current_user.id,
        }

    new_lifestyle = Lifestyle(user_id=current_user.id)
    _apply_survey_payload_to_lifestyle(
        new_lifestyle,
        profile_data,
        update_original_image=True,
    )
    db.add(new_lifestyle)
    db.commit()
    db.refresh(new_lifestyle)

    print(
        f"✅ Lifestyle 레코드 생성 완료 - lifestyle_id: {new_lifestyle.id}, user_id: {current_user.id}"
    )

    return {
        "success": True,
        "message": "생활습관 정보가 저장되었습니다.",
        "lifestyle_id": new_lifestyle.id,
        "user_id": current_user.id,
    }

