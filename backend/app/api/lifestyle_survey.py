from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import Optional, List, Dict, Any
from datetime import datetime
from app.database import get_db
from app.models import User, Lifestyle
from app.auth.security import verify_token
from pydantic import BaseModel

router = APIRouter()

# 입력을 위한 데이터 모델 (Lifestyle 테이블 스키마에 맞춤)
class LifestyleSurveyCreate(BaseModel):
    # 흡연
    smoking_status: str  # 비흡연/과거 흡연/현재 흡연
    smoking_amount: Optional[int] = None
    smoking_duration: Optional[int] = None
    
    # 운동
    exercise_daily_mins: int
    exercise_freq_per_week: int
    exercise_intensity: str  # 저강도/중강도/고강도
    exercise_type: str  # 유산소/무산소/기타/안함
    sedentary_hours_per_day: float
    exercise_regularity: str  # 규칙적/불규칙적
    exercise_duration_years: int
    stretching_habit: bool
    excercise_location: str  # 실내/실외/혼합
    
    # 수면
    sleep_hours: float
    sleep_quality: str  # 매우 좋음/좋음/보통/나쁨/매우 나쁨
    sleep_disorders: str  # 무/코골이/수면무호흡증/불면증/기타
    sleep_consistency: str  # 규칙적/불규칙적
    
    # 음주
    drinking_frequency: str  # 비음주/가끔/주1-2회/주3-4회/매일/기타
    drinking_details: Optional[List[Dict[str, Any]]] = None  # JSON 형식
    facial_flushing: bool
    drinking_duration_years: Optional[int] = None
    
    # 야외 활동 및 자외선 노출
    uv_activity_hours: Optional[List[str]] = None  # JSON 형식 ["12:00~12:30", ...]
    sunscreen_usage: str  # 매일/가끔/안함
    sunscreen_reapply_interval: Optional[str] = None
    
    # 체성분 데이터 (선택적)
    weight: Optional[float] = None
    height: Optional[float] = None
    muscle_mass: Optional[float] = None
    body_fat_mass: Optional[float] = None
    body_fat_percentage: Optional[float] = None
    bmi: Optional[float] = None
    bmr: Optional[float] = None
    whr: Optional[float] = None
    body_water: Optional[float] = None
    visceral_fat_level: Optional[float] = None
    
    # 목표 연도
    target_years: int

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
        smoking_status=profile_data.smoking_status,
        smoking_amount=profile_data.smoking_amount,
        smoking_duration=profile_data.smoking_duration,
        exercise_daily_mins=profile_data.exercise_daily_mins,
        exercise_freq_per_week=profile_data.exercise_freq_per_week,
        exercise_intensity=profile_data.exercise_intensity,
        exercise_type=profile_data.exercise_type,
        sedentary_hours_per_day=profile_data.sedentary_hours_per_day,
        exercise_regularity=profile_data.exercise_regularity,
        exercise_duration_years=profile_data.exercise_duration_years,
        stretching_habit=profile_data.stretching_habit,
        excercise_location=profile_data.excercise_location,
        sleep_hours=profile_data.sleep_hours,
        sleep_quality=profile_data.sleep_quality,
        sleep_disorders=profile_data.sleep_disorders,
        sleep_consistency=profile_data.sleep_consistency,
        drinking_frequency=profile_data.drinking_frequency,
        drinking_details=profile_data.drinking_details,
        facial_flushing=profile_data.facial_flushing,
        drinking_duration_years=profile_data.drinking_duration_years,
        uv_activity_hours=profile_data.uv_activity_hours,
        sunscreen_usage=profile_data.sunscreen_usage,
        sunscreen_reapply_interval=profile_data.sunscreen_reapply_interval,
        weight=profile_data.weight,
        height=profile_data.height,
        muscle_mass=profile_data.muscle_mass,
        body_fat_mass=profile_data.body_fat_mass,
        body_fat_percentage=profile_data.body_fat_percentage,
        bmi=profile_data.bmi,
        bmr=profile_data.bmr,
        whr=profile_data.whr,
        body_water=profile_data.body_water,
        visceral_fat_level=profile_data.visceral_fat_level,
        target_years=profile_data.target_years,
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

