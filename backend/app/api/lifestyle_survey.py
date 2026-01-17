from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import Optional, List, Dict, Any
from datetime import datetime
from app.database import get_db
from app.models import User, Lifestyle
from app.auth.security import verify_token
from pydantic import BaseModel

router = APIRouter()

# 입력을 위한 데이터 모델 (새로운 설문 구조)
class LifestyleSurveyCreate(BaseModel):
    # A. 주요 목표 (리포트 톤 라우팅) - multi choice
    outcomes: Optional[List[str]] = None  # ["wrinkle", "pigmentation", "hydration", "acne", "redness", "general_aging"]
    
    # B. Sleep & Rhythm (5)
    sleep_hours_weekday: Optional[float] = None  # 평균 수면시간(평일) 3~10h
    sleep_hours_weekend: Optional[float] = None  # 평균 수면시간(주말)
    sleep_quality_score: Optional[float] = None  # 수면의 질(주관) 0~10
    
    # C. UV / Photoaging (4)
    uv_exposure_10to16: Optional[str] = None  # 야외 노출(10~16시): <30m / 30~60 / 1~2h / >2h
    sunscreen_frequency: Optional[str] = None  # 선크림 사용 빈도: never/sometimes/most_days/daily_with_reapply
    sunscreen_reapply: Optional[str] = None  # 재도포(2~3시간 간격): never/rarely/sometimes/often
    outdoor_sports_uv: Optional[str] = None  # 야외스포츠(강한 UV): none/monthly/weekly
    
    # D. Alcohol & Smoking (4)
    drinking_days_per_week: Optional[str] = None  # 주당 음주일수: 0 / 1 / 2-3 / 4-5 / 6-7
    drinking_amount_per_session: Optional[str] = None  # 1회 음주량 (문자열)
    smoking_status: Optional[str] = None  # never/former/current
    smoking_amount_per_day: Optional[str] = None  # current일 경우: 갑/개비
    
    # E. Stress & Recovery (4)
    stress_score: Optional[float] = None  # 스트레스(지난 2주) 0~10
    caffeine_intake: Optional[str] = None  # 카페인 섭취량: 0 / 1 / 2 / 3+
    caffeine_timing: Optional[str] = None  # 카페인 섭취 시간대: before_noon / afternoon / evening
    
    # F. Activity & Metabolic (3)
    aerobic_weekly: Optional[str] = None  # 유산소(주당): 0 / 1-2 / 3-4 / 5+
    resistance_weekly: Optional[str] = None  # 근력(주당): 0 / 1 / 2 / 3+
    height: Optional[float] = None  # 키
    weight: Optional[float] = None  # 몸무게
    
    # Skin 상태 (3문항)
    skin_type: Optional[str] = None  # 피부 타입: dry/oily/combination/sensitive
    skin_concerns: Optional[List[str]] = None  # 주요 피부 고민: ["wrinkle", "pigmentation", "elasticity", "dryness", "redness", "acne"]
    skin_satisfaction: Optional[float] = None  # 현재 피부상태 만족도 0~10
    
    # 목표 연도
    target_years: int
    # 이미지 URL (기존 호환성)
    original_image_url: Optional[str] = None

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
    
    # Lifestyle 레코드 생성
    new_lifestyle = Lifestyle(
        user_id=current_user.id,
        outcomes=profile_data.outcomes,
        sleep_hours_weekday=profile_data.sleep_hours_weekday,
        sleep_hours_weekend=profile_data.sleep_hours_weekend,
        sleep_quality_score=profile_data.sleep_quality_score,
        uv_exposure_10to16=profile_data.uv_exposure_10to16,
        sunscreen_frequency=profile_data.sunscreen_frequency,
        sunscreen_reapply=profile_data.sunscreen_reapply,
        outdoor_sports_uv=profile_data.outdoor_sports_uv,
        drinking_days_per_week=profile_data.drinking_days_per_week,
        drinking_amount_per_session=profile_data.drinking_amount_per_session,
        smoking_status=profile_data.smoking_status,
        smoking_amount_per_day=profile_data.smoking_amount_per_day,
        stress_score=profile_data.stress_score,
        caffeine_intake=profile_data.caffeine_intake,
        caffeine_timing=profile_data.caffeine_timing,
        aerobic_weekly=profile_data.aerobic_weekly,
        resistance_weekly=profile_data.resistance_weekly,
        height=profile_data.height,
        weight=profile_data.weight,
        skin_type=profile_data.skin_type,
        skin_concerns=profile_data.skin_concerns,
        skin_satisfaction=profile_data.skin_satisfaction,
        target_years=profile_data.target_years,
        original_image_url=profile_data.original_image_url,
    )
    
    db.add(new_lifestyle)
    db.commit()
    db.refresh(new_lifestyle)
    
    print(f"✅ Lifestyle 레코드 저장 완료 - lifestyle_id: {new_lifestyle.id}, user_id: {current_user.id}")
    
    # 저장 성공 후 건강 리포트 생성은 클라이언트에서 별도로 호출
    # (리포트 생성에 시간이 걸릴 수 있으므로 비동기로 처리)
    
    return {
        "success": True,
        "message": "생활습관 정보가 저장되었습니다.",
        "lifestyle_id": new_lifestyle.id,
        "user_id": current_user.id
    }

