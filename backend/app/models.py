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
    #여성일 경우에만 임신 여부 입력 가능
    is_pregnant = Column(Boolean, nullable=True) #임신 여부(여성일 경우에만 값 있음) 



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
    original_image_url = Column(String, nullable=True)  # 사용자가 업로드한 원본 사진 경로 (설문 단계에서는 없을 수 있음)
    #처음에는 null허용인데 나중에는 미래 얼굴 사진이 반드시 생성되니 일단은 nullable=True
    generated_image_url = Column(String, nullable=True) # Gemini가 생성한 미래 얼굴 사진 경로
    
    # 이미지 생성 상태 및 파라미터 관리
    generation_status = Column(String, default="not_started", nullable=True)  # not_started -> pending -> processing -> completed -> failed
    image_gen_params = Column(JSON, nullable=True)  # AI 이미지 생성용 파라미터 예: {"wrinkles": 0.8, "pigmentation": 0.5, "target_age": 50}
      
    # A. 주요 목표 (리포트 톤 라우팅) - multi choice
    outcomes = Column(JSON, nullable=True)  # ["wrinkle", "elasticity", "pigmentation", "hydration", "hydration_barrier", "acne", "redness", "general_aging"]

    # B. Sleep & Rhythm (5)
    sleep_hours_weekday = Column(Float, nullable=True)  # 평균 수면시간(평일) 3~10h
    sleep_hours_weekend = Column(Float, nullable=True)  # 평균 수면시간(주말)
    sleep_quality_score = Column(Float, nullable=True)  # 수면의 질(주관) 0~10

    # C. UV / Photoaging (4)
    uv_exposure_10to16 = Column(String, nullable=True)  # 야외 노출(10~16시): <30m / 30~60 / 1~2h / >2h
    sunscreen_frequency = Column(String, nullable=True)  # 선크림 사용 빈도: never/sometimes/most_days/daily_with_reapply
    sunscreen_reapply = Column(String, nullable=True)  # 재도포(2~3시간 간격): never/rarely/sometimes/often
    outdoor_sports_uv = Column(String, nullable=True)  # 야외스포츠(강한 UV): none/monthly/weekly

    # D. Alcohol & Smoking (4)
    drinking_days_per_week = Column(String, nullable=True)  # 주당 음주일수: 0 / 1 / 2-3 / 4-5 / 6-7
    drinking_amount_per_session = Column(String, nullable=True)  # 1회 음주량 (문자열)
    smoking_status = Column(String, nullable=True)  # never/former/current
    smoking_amount_per_day = Column(String, nullable=True)  # current일 경우: 갑/개비

    # E. Stress & Recovery (4)
    stress_score = Column(Float, nullable=True)  # 스트레스(지난 2주) 0~10
    caffeine_intake = Column(String, nullable=True)  # 카페인 섭취량: 0 / 1 / 2 / 3+
    caffeine_timing = Column(String, nullable=True)  # 카페인 섭취 시간대: before_noon / afternoon / evening

    # F. Activity & Metabolic (3)
    aerobic_weekly = Column(String, nullable=True)  # 유산소(주당): 0 / 1-2 / 3-4 / 5+
    resistance_weekly = Column(String, nullable=True)  # 근력(주당): 0 / 1 / 2 / 3+
    height = Column(Float, nullable=True)  # 키
    weight = Column(Float, nullable=True)  # 몸무게

    # Skin 상태 (3문항)
    skin_type = Column(String, nullable=True)  # 피부 타입: dry/oily/combination/sensitive
    skin_concerns = Column(JSON, nullable=True)  # 주요 피부 고민: ["wrinkle", "pigmentation", "elasticity", "dryness", "redness", "acne"]
    skin_satisfaction = Column(Float, nullable=True)  # 현재 피부상태 만족도 0~10


    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    #몇년후로 가고 싶은지 설정
    target_years = Column(Integer)
    
    # 건강 리포트 (LangGraph로 생성된 리포트 저장)
    health_report = Column(JSON, nullable=True)  # 리포트 섹션별 데이터 및 통합 리포트
    health_report_generated_at = Column(DateTime(timezone=True), nullable=True)  # 리포트 생성 시간

    # Notion 정보
    notion_page_id = Column(String, nullable=True)
    notion_url = Column(String, nullable=True)


    # Lifestyle과 User 간의 다대일 관계 설정
    owner=relationship("User", back_populates="lifestyles")