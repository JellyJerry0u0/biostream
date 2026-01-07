#DB 조회 관련 함수
#SQLAlchemy ORM 사용하여 Gemini가 읽기 좋은 형식으로 데이터 반환

import os
from sqlalchemy import create_engine
from dotenv import load_dotenv
from datetime import date
from app.models import User, Lifestyle #DB 모델 임포트
from sqlalchemy.orm import sessionmaker, Session


load_dotenv()

#DB 연결 설정
# 실행 환경 플래그 확인 (도커 환경이면 true)
is_docker = os.getenv("RUNNING_IN_DOCKER") == "true"

# 환경에 맞는 호스트 선택
# 도커 내부라면 서비스 명칭인 'db'를 사용하고, 로컬이면 'localhost'를 사용합니다.
db_host = os.getenv("DB_HOST_DOCKER") if is_docker else os.getenv("DB_HOST_LOCAL")

db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")
db_name = os.getenv("DB_NAME")
db_port = os.getenv("DB_PORT")

DATABASE_URL = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"

# 엔진 생성 (연결 실패 시 재시도를 위한 pool 설정 포함)
engine = create_engine(DATABASE_URL, pool_size=10, max_overflow=20)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


#DB 세션하고 닫아주는 함수
def get_db():
    db = SessionLocal()
    try:
        return db
    finally:
        db.close()

#생년월일을 바탕으로 만나이 계산
def calculate_age(birthdate: date) -> int:
    today = date.today()
    age = today.year - birthdate.year - ((today.month, today.day) < (birthdate.month, birthdate.day))
    return age

#LLM이 이해하기 쉬운 형식으로 사용자 정보 반환
def fetch_user_aging_context(user_id:int):
    """
    User에서 생년월일과 성별, Lifestyle에서 흡연 및 운동 습관 정보를 조회하여
    """
    db=get_db()
    try:
        #사용자 정보 조회
        user=db.query(User).filter(User.id==user_id).first()
        if not user:
            return {"error":"User not found"}
        
        #사용자의 가장 최근 설문조사 데이터 조회
        lifestyle=db.query(Lifestyle).filter(Lifestyle.user_id==user_id).order_by(Lifestyle.created_at.desc()).first()
        if not lifestyle:
            return {"error":"Lifestyle data not found for user"}
        
     

        #LLM이 이해하기 쉬운 형식으로 데이터 구성
        return{
            "profile":{ #User 테이블에서 가져온 변하지 않는 정보
                "age": f"{calculate_age(user.birthdate)} years",
                "gender": user.gender
            },
            "lifestyle":{ #listyle 테이블에서 가져온 최근 설문 정보 중 생활습관에 관련된 정보
                "smoking":{
                    "smoking_status": lifestyle.smoking_status,
                    "smoking_amount_per_day": f"{lifestyle.smoking_amount} cigarettes",
                    "smoking_duration_years": f"{lifestyle.smoking_duration} years"
                },
                "exercise":{
                    "daily_exercise_minutes": f"{lifestyle.exercise_daily_mins} minutes",
                    "weekly_exercise_frequency": {lifestyle.exercise_freq_per_week},
                    "exercise_intensity": lifestyle.exercise_intensity,
                    "exercise_type": lifestyle.exercise_type,
                    "sedentary_hours_per_day": f"{lifestyle.sedentary_hours_per_day} hours",
                    "exercise_regularity": lifestyle.exercise_regularity,
                    "exercise_duration_years": f"{lifestyle.exercise_duration_years} years",
                    "stretching_habit": lifestyle.stretching_habit,
                    "exercise_location": lifestyle.excercise_location
                },
                "sleep":{
                    "average_sleep_hours": f"{lifestyle.sleep_hours} hours",
                    "sleep_quality": lifestyle.sleep_quality,
                    "sleep_disorders": lifestyle.sleep_disorders,
                    "sleep_consistency": lifestyle.sleep_consistency
                },
                "drinking":{
                    "drinking_frequency": lifestyle.drinking_frequency,
                    "drinking_details": lifestyle.drinking_details,
                    "facial_flushing": lifestyle.facial_flushing,
                    "drinking_duration_years": f"{lifestyle.drinking_duration_years} years"
                },
                "uv":{
                    "uv_activity_hours": lifestyle.uv_actuvity_hours,
                    "sunscreen_usage": lifestyle.sunscreen_usage,
                    "sunscreen_reapply_interval": lifestyle.sunscreen_reapply_interval
                }
                

            },
            "bodystate":{ #Lifestyle 테이블에서 가져온 최근 설문 정보 중 신체 상태에 관련된 정보
                "weight_kg": f"{lifestyle.weight}kg", #단위 명시
                "height_cm": f"{lifestyle.height}cm", #단위 명시
                "muscle_mass_kg": f"{lifestyle.muscle_mass}kg", #단위 명시
                "body_fat_mass_kg": f"{lifestyle.body_fat_mass}kg", #단위 명시
                "body_fat_percentage": f"{lifestyle.body_fat_percentage}%", #단위 명시
                "bmi": lifestyle.bmi, #단위 없음
                "bmr": f"{lifestyle.bmr} kcal", #기초대사량 단위는 kcal로 고정
                "whr": lifestyle.whr, 
                "body_water": f"{lifestyle.body_water}L", #단위 명시
                "visceral_fat_level": f"{lifestyle.visceral_fat_level}Lv",
            },
            "target_age": f"{lifestyle.target_years} years after" #몇년후로 가고 싶은지

        }
    
    except Exception as e:
        return {"error": f"Database query failed: {str(e)}"}
