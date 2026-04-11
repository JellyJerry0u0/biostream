from sqlalchemy import Column, Integer, String, DateTime, Date, ForeignKey, Float, Boolean, JSON, Text
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
    # 흡연 여부: never / former / current (회원가입 시 입력, 비흡연자면 설문에서 흡연 섹션 생략)
    smoking_status = Column(String, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # User와 Lifestyle 간의 일대다 관계 설정(한명의 유저는 여러번 설문 조사 가능)
    lifestyles = relationship("Lifestyle", back_populates="owner")
    profile = relationship("UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    health_data_records = relationship("HealthData", back_populates="user")
    daily_lifestyle_snapshots = relationship("DailyLifestyleSnapshot", back_populates="user", cascade="all, delete-orphan")
    device_tokens = relationship("UserDeviceToken", back_populates="user", cascade="all, delete-orphan")
    committed_actions = relationship("UserCommittedAction", back_populates="user", cascade="all, delete-orphan")
    coach_agent_state_row = relationship(
        "UserCoachAgentState",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    profile_image_url = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="profile")


#설문 조사 데이터 모델
class Lifestyle(Base):
    __tablename__ = "lifestyles" #테이블 이름 지정

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))  # 어떤 유저의 설문인지 식별하기 위한 외래키
     
    #사진 정보 필드
    original_image_url = Column(String, nullable=True)  # 사용자가 업로드한 원본 사진 경로 (설문 단계에서는 없을 수 있음)
    #처음에는 null허용인데 나중에는 미래 얼굴 사진이 반드시 생성되니 일단은 nullable=True
    # /generate→설문 기반 skin-edit 최종(리포트 결과 슬라이더 오른쪽·리포트 JSON·미래얼굴 오른쪽)
    generated_image_url = Column(String, nullable=True)
    # 동일 /generate 픽셀 + skin-edit 습관 점수 전부 100(미래 얼굴 탭 슬라이더 왼쪽만)
    ideal_habits_skin_image_url = Column(String, nullable=True)

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
    sunscreen_frequency = Column(String, nullable=True)  # 선크림 주 N회: 0/1/2-3/4-5/6-7 (레거시: never/sometimes/most_days/daily_with_reapply)
    sunscreen_reapply = Column(String, nullable=True)  # 재도포(2~3시간 간격): never/rarely/sometimes/often
    outdoor_sports_uv = Column(String, nullable=True)  # 야외스포츠(강한 UV): none/monthly/weekly

    # D. Alcohol & Smoking (4)
    drinking_days_per_week = Column(String, nullable=True)  # 주당 음주일수: 0 / 1 / 2-3 / 4-5 / 6-7
    drinking_amount_per_session = Column(String, nullable=True)  # 레거시 1회 음주량 (미사용 가능)
    smoking_status = Column(String, nullable=True)  # never/former/current
    smoking_amount_per_day = Column(String, nullable=True)  # 레거시 하루 흡연량 (미사용 가능)
    smoking_days_per_week = Column(String, nullable=True)  # 주당 흡연일수: 0 / 1 / 2-3 / 4-5 / 6-7

    # E. Stress & Recovery
    stress_score = Column(Float, nullable=True)  # 스트레스(지난 2주) 0~10

    # F. Activity & Metabolic (3)
    aerobic_weekly = Column(String, nullable=True)  # 유산소(주당): 0 / 1-2 / 3-4 / 5+
    resistance_weekly = Column(String, nullable=True)  # 근력(주당): 0 / 1 / 2 / 3+
    height = Column(Float, nullable=True)  # 키
    weight = Column(Float, nullable=True)  # 몸무게

    # Skin 상태
    skin_type = Column(String, nullable=True)  # 피부 타입: dry/oily/combination/sensitive
    skin_satisfaction = Column(Float, nullable=True)  # 현재 피부상태 만족도 0~10


    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    #몇년후로 가고 싶은지 설정
    target_years = Column(Integer)

    # Notion 정보 (리포트 저장 시 함께 저장됨, Report 테이블과 함께 사용)
    notion_page_id = Column(String, nullable=True)
    notion_url = Column(String, nullable=True)


    # Lifestyle과 User 간의 다대일 관계 설정
    owner=relationship("User", back_populates="lifestyles")
    report = relationship("Report", back_populates="lifestyle", uselist=False, cascade="all, delete-orphan")


class Report(Base):
    """건강 리포트 (lifestyles.health_report에서 분리)"""
    __tablename__ = "health_reports"

    id = Column(Integer, primary_key=True, index=True)
    lifestyle_id = Column(Integer, ForeignKey("lifestyles.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    report = Column(JSON, nullable=False)  # 리포트 JSON (sections, cards 등)
    generated_at = Column(DateTime(timezone=True), nullable=False)

    lifestyle = relationship("Lifestyle", back_populates="report")


class HealthData(Base):
    __tablename__ = "health_data"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    steps = Column(Integer, default=0, nullable=False)
    sleep_minutes = Column(Integer, default=0, nullable=False)
    distance_meters = Column(Float, default=0.0, nullable=False)
    oxygen_saturation = Column(Float, default=0.0, nullable=False)
    average_speed_mps = Column(Float, default=0.0, nullable=False)
    active_calories_kcal = Column(Float, default=0.0, nullable=False)
    exercise_minutes = Column(Integer, default=0, nullable=False)
    fitness_score = Column(Float, default=0.0, nullable=False)
    weight_kg = Column(Float, default=0.0, nullable=False)
    height_cm = Column(Float, default=0.0, nullable=False)
    body_fat_percentage = Column(Float, default=0.0, nullable=False)
    vo2_max = Column(Float, default=0.0, nullable=False)
    blood_glucose_mg_dl = Column(Float, default=0.0, nullable=False)
    outdoor_prompt_count = Column(Integer, default=0, nullable=False)
    outdoor_yes_count = Column(Integer, default=0, nullable=False)
    outdoor_no_count = Column(Integer, default=0, nullable=False)
    outdoor_unknown_count = Column(Integer, default=0, nullable=False)
    uv_exposure_score = Column(Float, default=0.0, nullable=False)
    uv_source = Column(String, default="self_reported_step_prompt", nullable=False)
    sync_date = Column(Date, index=True, nullable=False)
    is_processed = Column(Boolean, default=False, nullable=False)
    notification_sent = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="health_data_records")


class DailyLifestyleSnapshot(Base):
    """오늘의 나의 생활 일별 스냅샷 (체중/키/음주/흡연/스트레스/수면/운동/UV/수면의질)"""
    __tablename__ = "daily_lifestyle_snapshot"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    snapshot_date = Column(Date, nullable=False, index=True)
    weight_kg = Column(Float, nullable=True)
    height_cm = Column(Float, nullable=True)
    drinking_days_per_week = Column(String(20), nullable=True)
    smoking_status = Column(String(50), nullable=True)
    stress_score = Column(Float, nullable=True)
    sleep_minutes = Column(Integer, nullable=True)
    sleep_quality_score = Column(Float, nullable=True)  # 0~10
    aerobic_sessions_30min = Column(Integer, nullable=True)
    resistance_sessions_30min = Column(Integer, nullable=True)
    uv_outdoor_10to16 = Column(String(20), nullable=True)  # <30m, 30~60, 1~2h, >2h
    sunscreen_applied = Column(Boolean, nullable=True)  # 오늘 선크림 도포 여부
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="daily_lifestyle_snapshots")


class UserDeviceToken(Base):
    __tablename__ = "user_device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    device_token = Column(String, nullable=False, index=True)
    platform = Column(String, nullable=False, default="android")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="device_tokens")


class CoachInAppNudge(Base):
    """스냅샷 최초 저장 등 비동기 코치 메시지 — 앱이 챗봇 탭을 열 때 조회·소비"""

    __tablename__ = "coach_in_app_nudge"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    body = Column(String, nullable=False)
    consumed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", backref="coach_in_app_nudges")


class UserCommittedAction(Base):
    """사용자가 리포트에서 저장한 생활습관(전역 활성 개수 상한은 API에서 적용)"""
    __tablename__ = "user_committed_actions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    lifestyle_id = Column(Integer, ForeignKey("lifestyles.id", ondelete="CASCADE"), nullable=False, index=True)
    section_key = Column(String, nullable=False)  # goals, sleep, uv, smoking, drinking, stress, activity
    action_title = Column(String, nullable=False)  # 스냅샷 (리포트 변경 대비)
    action_detail = Column(Text, nullable=True)  # 스냅샷
    committed_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    status = Column(String, default="active", nullable=False)  # active / completed / abandoned

    user = relationship("User", back_populates="committed_actions")
    check_ins = relationship("ActionCheckIn", back_populates="committed_action", cascade="all, delete-orphan")


class ActionCheckIn(Base):
    """습관 실천 일별 기록 (했어요/못했어요)"""
    __tablename__ = "action_check_ins"

    id = Column(Integer, primary_key=True, index=True)
    committed_action_id = Column(
        Integer,
        ForeignKey("user_committed_actions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    check_date = Column(Date, nullable=False)  # 일 단위
    completed = Column(Boolean, nullable=False)  # 했어요 True / 못했어요 False
    note = Column(Text, nullable=True)  # 선택 메모

    committed_action = relationship("UserCommittedAction", back_populates="check_ins")


class UserCoachAgentState(Base):
    """코치 LangGraph 적응형 상태 (목표·에피소드·코칭 메모리·대기 중 목표 제안)"""

    __tablename__ = "user_coach_agent_states"

    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    state = Column(JSON, nullable=False, default=dict)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="coach_agent_state_row")