from sqlalchemy import Column, Integer, String, DateTime,Date,ForeignKey, Float, Boolean , JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base
#SQLAlchemy 라는 ORM을 사용해 PostgreSQL 데이터베이스와 상호작용하기 위한 모델 정의

class User(Base):
    __tablename__ = "users" #테이블 이름 지정

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True) # 일반 가입용, 카카오 전용 가입자는 비번이 없을 수 있음
    kakao_id = Column(String, unique=True,index=True, nullable=True) # 카카오 연동용
    nickname = Column(String, nullable=False)
    
    #기존에는 설문에서 받았던 생년월일,성별을 아예 사용자 테이블에 추가(한번 입력받는 고정 값이니)
    birthdate = Column(Date, nullable=True) #시/분/초 필요없으니 Date
    gender= Column(String, nullable=True) 



    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # User와 Lifestyle 간의 일대다 관계 설정(한명의 유저는 여러번 설문 조사 가능)
    lifestyles=relationship("Lifestyle", back_populates="owner")


#설문 조사 데이터 모델
class Lifestyle(Base):
    __tablename__ = "lifestyles" #테이블 이름 지정

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))  # 어떤 유저의 설문인지 식별하기 위한 외래키
     
    #사진 정보 필드
    original_image_url = Column(String)  # 사용자가 업로드한 원본 사진 경로
    #처음에는 null허용인데 나중에는 미래 얼굴 사진이 반드시 생성되니 일단은 nullable=True
    generated_image_url = Column(String, nullable=True) # Gemini가 생성한 미래 얼굴 사진 경로
      

      
    #1. 흡연
    #흡연 상태 (비흡연/과거 흡연/현재 흡연) 
    smoking_status = Column(String) 
    
    #비흡연자일경우 아래 항목은 Null
    #현재 흡연자는 과거 흡연량, 과거 흡연 기간 입력
    smoking_amount=Column(Integer, nullable=True) #하루 흡연량(개비)
    smoking_duration=Column(Integer, nullable=True) #총 흡연 기간(년)


    #2. 운동
    exercise_daily_mins= Column(Integer) #하루 평균 운동 시간(분)
    exercise_freq_per_week= Column(Integer) #주당 운동 빈도(횟수)
    exercise_intensity= Column(String) #운동 강도(저강도/중강도/고강도)
    exercise_type= Column(String) #주로 하는 운동 종류(유산소/무산소/기타(직접입력)/안함)
    sedentary_hours_per_day= Column(Float) #하루 평균 앉아있는 시간(시간)
    exercise_regularity= Column(String) #운동 규칙성(규칙적/불규칙적)
    exercise_duration_years = Column(Integer) #운동 지속 기간(년)
    stretching_habit= Column(Boolean) #스트레칭 습관 여부(예/아니오)
    excercise_location= Column(String) #주로 운동하는 장소(실내/실외/혼합)=> 광노화관련

    #3. 수면
    sleep_hours=Column(Float) #평균 수면 시간(시간)
    sleep_quality=Column(String) #수면의 질(매우 좋음/좋음/보통/나쁨/매우 나쁨)
    sleep_disorders=Column(String) #수면 장애 여부(무/코골이/수면무호흡증/불면증/기타)
    sleep_consistency=Column(String) #수면 패턴의 일관성(규칙적/불규칙적)

    #4. 음주
    drinking_frequency=Column(String) #음주 빈도(비음주/가끔/주1-2회/주3-4회/매일/기타(직접입력))
    #1회 음주 시 평균 음주량(JSON 형식)
    # 예시 데이터: 
    # [
    #   {"type": "소주", "glass": "소주잔", "count": 5},
    #   {"type": "맥주", "glass": "500cc", "count": 2}
    # ]
    drinking_details=Column(JSON,nullable=True)
    facial_flushing = Column(Boolean)   # 음주 시 안면 홍조 여부
    drinking_duration_years = Column(Integer) # 총 음주 경력 (년)

    #5. 야외 활동 및 자외선 노출
    uv_activity_hours=Column(JSON) # 여러 시간대를 입력받으므로 JSON 타입으로 저장 (예: ["12:00~12:30", "15:00~16:00"])  # 오타 수정: uv_actuvity_hours -> uv_activity_hours
    sunscreen_usage=Column(String) #자외선 차단제 사용 빈도(매일/가끔/안함)
    sunscreen_reapply_interval = Column(String) # 선크림 재도포 주기

    #6. 체성분 데이터(인바디 측정시 알 수 있는 정보들, 선택적 입력)
    weight = Column(Float, nullable=True)
    height = Column(Float, nullable=True)
    muscle_mass = Column(Float, nullable=True) #골격근량
    body_fat_mass = Column(Float, nullable=True) #체지방량
    body_fat_percentage = Column(Float, nullable=True) #체지방률
    bmi = Column(Float, nullable=True) #BMI
    bmr= Column(Float, nullable=True) #기초대사량
    whr= Column(Float, nullable=True) #복부지방률
    body_water = Column(Float, nullable=True) #체수분량
    visceral_fat_level = Column(Float, nullable=True) #내장지방레벨

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    #몇년후로 가고 싶은지 설정
    target_years = Column(Integer)


    # Lifestyle과 User 간의 다대일 관계 설정
    owner=relationship("User", back_populates="lifestyles")