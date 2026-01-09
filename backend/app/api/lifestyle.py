from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import Optional
from datetime import time
from app.database import get_db
from app.models import User, UserLifestyleProfile, SmokingStatus, SecondhandSmokeExposure, SleepScheduleRegular, AlcoholFrequency, BingeFrequency, SunscreenUseFrequency, SunscreenReapply, OutdoorTypeMain, PeakSunExposure
from app.auth.security import verify_token
from pydantic import BaseModel

router = APIRouter()

# 입력을 위한 데이터 모델
class LifestyleProfileCreate(BaseModel):
    # 흡연
    smoking_status: str
    cigs_per_day: Optional[int] = None
    years_smoked: Optional[float] = None
    years_since_quit: Optional[float] = None
    secondhand_smoke_exposure: Optional[str] = None
    
    # 운동
    mvpa_days_per_week: int
    mvpa_minutes_per_day: int
    resistance_days_per_week: Optional[int] = None
    resistance_minutes_per_day: Optional[int] = None
    steps_per_day: Optional[int] = None
    
    # 수면
    sleep_hours_weekday: float
    sleep_hours_weekend: float
    sleep_quality: Optional[int] = None
    sleep_schedule_regular: Optional[str] = None
    bedtime_typical: Optional[str] = None  # "HH:MM" 형식
    waketime_typical: Optional[str] = None  # "HH:MM" 형식
    
    # 음주
    alcohol_frequency: str
    drinks_per_occasion: float
    binge_frequency: Optional[str] = None
    
    # 자외선
    sun_exposure_minutes_per_day: int
    sunscreen_use_frequency: str
    sunscreen_spf: Optional[int] = None
    sunscreen_reapply: Optional[str] = None
    
    # 야외활동
    outdoor_minutes_per_day: int
    outdoor_type_main: Optional[str] = None
    peak_sun_exposure: Optional[str] = None

def get_current_user(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)):
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
        raise HTTPException(status_code=401, detail="인증 실패")

def parse_time(time_str: Optional[str]) -> Optional[time]:
    if not time_str:
        return None
    try:
        parts = time_str.split(":")
        return time(int(parts[0]), int(parts[1]))
    except:
        return None

@router.post("/lifestyle-profile")
def create_or_update_lifestyle_profile(
    profile_data: LifestyleProfileCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # smoking_status가 never이면 관련 필드들을 None으로 설정
    if profile_data.smoking_status == "never":
        profile_data.cigs_per_day = None
        profile_data.years_smoked = None
        profile_data.years_since_quit = None
        profile_data.secondhand_smoke_exposure = None
    
    # 기존 프로필이 있는지 확인
    existing_profile = db.query(UserLifestyleProfile).filter(
        UserLifestyleProfile.user_id == current_user.id
    ).first()
    
    # 시간 문자열을 Time 객체로 변환
    bedtime = parse_time(profile_data.bedtime_typical)
    waketime = parse_time(profile_data.waketime_typical)
    
    if existing_profile:
        # 업데이트
        existing_profile.smoking_status = SmokingStatus(profile_data.smoking_status)
        existing_profile.cigs_per_day = profile_data.cigs_per_day
        existing_profile.years_smoked = profile_data.years_smoked
        existing_profile.years_since_quit = profile_data.years_since_quit
        existing_profile.secondhand_smoke_exposure = SecondhandSmokeExposure(profile_data.secondhand_smoke_exposure) if profile_data.secondhand_smoke_exposure else None
        existing_profile.mvpa_days_per_week = profile_data.mvpa_days_per_week
        existing_profile.mvpa_minutes_per_day = profile_data.mvpa_minutes_per_day
        existing_profile.resistance_days_per_week = profile_data.resistance_days_per_week
        existing_profile.resistance_minutes_per_day = profile_data.resistance_minutes_per_day
        existing_profile.steps_per_day = profile_data.steps_per_day
        existing_profile.sleep_hours_weekday = profile_data.sleep_hours_weekday
        existing_profile.sleep_hours_weekend = profile_data.sleep_hours_weekend
        existing_profile.sleep_quality = profile_data.sleep_quality
        existing_profile.sleep_schedule_regular = SleepScheduleRegular(profile_data.sleep_schedule_regular) if profile_data.sleep_schedule_regular else None
        existing_profile.bedtime_typical = bedtime
        existing_profile.waketime_typical = waketime
        existing_profile.alcohol_frequency = AlcoholFrequency(profile_data.alcohol_frequency)
        existing_profile.drinks_per_occasion = profile_data.drinks_per_occasion
        existing_profile.binge_frequency = BingeFrequency(profile_data.binge_frequency) if profile_data.binge_frequency else None
        existing_profile.sun_exposure_minutes_per_day = profile_data.sun_exposure_minutes_per_day
        existing_profile.sunscreen_use_frequency = SunscreenUseFrequency(profile_data.sunscreen_use_frequency)
        existing_profile.sunscreen_spf = profile_data.sunscreen_spf
        existing_profile.sunscreen_reapply = SunscreenReapply(profile_data.sunscreen_reapply) if profile_data.sunscreen_reapply else None
        existing_profile.outdoor_minutes_per_day = profile_data.outdoor_minutes_per_day
        existing_profile.outdoor_type_main = OutdoorTypeMain(profile_data.outdoor_type_main) if profile_data.outdoor_type_main else None
        existing_profile.peak_sun_exposure = PeakSunExposure(profile_data.peak_sun_exposure) if profile_data.peak_sun_exposure else None
    else:
        # 새로 생성
        new_profile = UserLifestyleProfile(
            user_id=current_user.id,
            smoking_status=SmokingStatus(profile_data.smoking_status),
            cigs_per_day=profile_data.cigs_per_day,
            years_smoked=profile_data.years_smoked,
            years_since_quit=profile_data.years_since_quit,
            secondhand_smoke_exposure=SecondhandSmokeExposure(profile_data.secondhand_smoke_exposure) if profile_data.secondhand_smoke_exposure else None,
            mvpa_days_per_week=profile_data.mvpa_days_per_week,
            mvpa_minutes_per_day=profile_data.mvpa_minutes_per_day,
            resistance_days_per_week=profile_data.resistance_days_per_week,
            resistance_minutes_per_day=profile_data.resistance_minutes_per_day,
            steps_per_day=profile_data.steps_per_day,
            sleep_hours_weekday=profile_data.sleep_hours_weekday,
            sleep_hours_weekend=profile_data.sleep_hours_weekend,
            sleep_quality=profile_data.sleep_quality,
            sleep_schedule_regular=SleepScheduleRegular(profile_data.sleep_schedule_regular) if profile_data.sleep_schedule_regular else None,
            bedtime_typical=bedtime,
            waketime_typical=waketime,
            alcohol_frequency=AlcoholFrequency(profile_data.alcohol_frequency),
            drinks_per_occasion=profile_data.drinks_per_occasion,
            binge_frequency=BingeFrequency(profile_data.binge_frequency) if profile_data.binge_frequency else None,
            sun_exposure_minutes_per_day=profile_data.sun_exposure_minutes_per_day,
            sunscreen_use_frequency=SunscreenUseFrequency(profile_data.sunscreen_use_frequency),
            sunscreen_spf=profile_data.sunscreen_spf,
            sunscreen_reapply=SunscreenReapply(profile_data.sunscreen_reapply) if profile_data.sunscreen_reapply else None,
            outdoor_minutes_per_day=profile_data.outdoor_minutes_per_day,
            outdoor_type_main=OutdoorTypeMain(profile_data.outdoor_type_main) if profile_data.outdoor_type_main else None,
            peak_sun_exposure=PeakSunExposure(profile_data.peak_sun_exposure) if profile_data.peak_sun_exposure else None,
        )
        db.add(new_profile)
    
    db.commit()
    return {"message": "생활습관 정보가 저장되었습니다."}

