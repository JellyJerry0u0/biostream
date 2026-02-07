#DB 조회 관련 함수
#SQLAlchemy ORM 사용하여 Gemini가 읽기 좋은 형식으로 데이터 반환

import os
from sqlalchemy import create_engine
from dotenv import load_dotenv
from datetime import date

from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.exc import OperationalError  # DB 연결 관련 예외 처리를 위해 필요


from pathlib import Path

load_dotenv()


#DB 연결 설정
# 실행 환경 플래그 확인 (도커 환경이면 true)
is_docker = os.getenv("RUNNING_IN_DOCKER") == "true"

# 환경에 맞는 호스트 선택
# 도커 내부라면 서비스 명칭인 'db'를 사용하고, 로컬이면 'localhost'를 사용합니다.
# 환경변수가 없을 경우 기본값 사용
db_host = os.getenv("DB_HOST_DOCKER") if is_docker else os.getenv("DB_HOST_LOCAL", "localhost")
db_user = os.getenv("DB_USER", "myuser")
db_password = os.getenv("DB_PASSWORD", "mypassword")
db_name = os.getenv("DB_NAME", "biostream")
db_port = os.getenv("DB_PORT", "5432")

DATABASE_URL = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"

# 엔진 생성 (연결 실패 시 재시도를 위한 pool 설정 포함)
engine = create_engine(DATABASE_URL, pool_size=10, max_overflow=20, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)




#생년월일을 바탕으로 만나이 계산
def calculate_age(birthdate: date) -> int:
    today = date.today()
    age = today.year - birthdate.year - ((today.month, today.day) < (birthdate.month, birthdate.day))
    return age

#LLM이 이해하기 쉬운 형식으로 사용자 정보 반환
def fetch_user_aging_context(user_id:int):
    """
    MCP 서버 시작 지점이 아닌, Tool이 실제 호출될때 DB 연결

    User에서 생년월일과 성별, Lifestyle에서 흡연 및 운동 습관 정보를 조회하여
    """
    import sys
    import os
    
    # 컨테이너 환경에서 models에 접근하기 위한 경로 설정
    # /app이 WORKDIR이고, mcp_server는 /app/mcp_server에, models는 /app/app/models.py에 있음
    # PYTHONPATH가 /app으로 설정되어 있으므로 직접 import 가능
    try:
        from app.models import User, Lifestyle
    except ImportError:
        # fallback: sys.path에 직접 추가
        app_path = os.path.join(os.path.dirname(__file__), "../..")
        app_path = os.path.abspath(app_path)
        if app_path not in sys.path:
            sys.path.insert(0, app_path)
        from app.models import User, Lifestyle

    db = SessionLocal()
    try:
        #사용자 정보 조회
        user=db.query(User).filter(User.id==user_id).first()
        if not user:
            return {"error":"User not found"}
        
        #사용자의 가장 최근 설문조사 데이터 조회
        lifestyle=db.query(Lifestyle).filter(Lifestyle.user_id==user_id).order_by(Lifestyle.created_at.desc()).first()
        if not lifestyle:
            return {"error":"Lifestyle data not found for user"}
        
     

        # 디버깅: DB에서 조회된 원본 데이터 출력
        print(f"🔍 [DB 조회] User ID: {user.id}, Lifestyle ID: {lifestyle.id}")
        print(f"🔍 [DB 조회] sleep_hours_weekday: {lifestyle.sleep_hours_weekday}")
        print(f"🔍 [DB 조회] sleep_quality_score: {lifestyle.sleep_quality_score}")
        print(f"🔍 [DB 조회] stress_score: {lifestyle.stress_score}")
        print(f"🔍 [DB 조회] smoking_status: {lifestyle.smoking_status}")
        print(f"🔍 [DB 조회] outcomes: {lifestyle.outcomes}")
        
        #LLM이 이해하기 쉬운 형식으로 데이터 구성 (새로운 모델 구조에 맞게 수정)
        result = {
            "lifestyle_id": lifestyle.id,  # lifestyle_id 추가
            "profile":{ #User 테이블에서 가져온 변하지 않는 정보
                "age": f"{calculate_age(user.birthdate)} years" if user.birthdate else None,
                "gender": user.gender
            },
            "lifestyle":{ #Lifestyle 테이블에서 가져온 최근 설문 정보 중 생활습관에 관련된 정보
                "outcomes": lifestyle.outcomes if lifestyle.outcomes else None,
                "smoking":{
                    "smoking_status": lifestyle.smoking_status,
                    "smoking_amount_per_day": lifestyle.smoking_amount_per_day if lifestyle.smoking_amount_per_day else None,
                },
                "sleep":{
                    "sleep_hours_weekday": f"{lifestyle.sleep_hours_weekday} hours" if lifestyle.sleep_hours_weekday is not None else None,
                    "sleep_hours_weekend": f"{lifestyle.sleep_hours_weekend} hours" if lifestyle.sleep_hours_weekend is not None else None,
                    "sleep_quality_score": f"{lifestyle.sleep_quality_score}/10" if lifestyle.sleep_quality_score is not None else None
                },
                "uv":{
                    "uv_exposure_10to16": lifestyle.uv_exposure_10to16,
                    "sunscreen_frequency": lifestyle.sunscreen_frequency,
                    "sunscreen_reapply": lifestyle.sunscreen_reapply,
                    "outdoor_sports_uv": lifestyle.outdoor_sports_uv
                },
                "drinking":{
                    "drinking_days_per_week": lifestyle.drinking_days_per_week,
                    "drinking_amount_per_session": lifestyle.drinking_amount_per_session
                },
                "stress":{
                    "stress_score": f"{lifestyle.stress_score}/10" if lifestyle.stress_score is not None else None,
                    "caffeine_intake": lifestyle.caffeine_intake,
                    "caffeine_timing": lifestyle.caffeine_timing
                },
                "activity":{
                    "aerobic_weekly": lifestyle.aerobic_weekly,
                    "resistance_weekly": lifestyle.resistance_weekly
                }
            },
            "bodystate":{ #Lifestyle 테이블에서 가져온 최근 설문 정보 중 신체 상태에 관련된 정보
                "weight_kg": f"{lifestyle.weight}kg" if lifestyle.weight is not None else None,
                "height_cm": f"{lifestyle.height}cm" if lifestyle.height is not None else None,
            },
            "skin":{
                "skin_type": lifestyle.skin_type,
                "skin_concerns": lifestyle.skin_concerns if lifestyle.skin_concerns else None,
                "skin_satisfaction": f"{lifestyle.skin_satisfaction}/10" if lifestyle.skin_satisfaction is not None else None
            },
            "target_age": f"{lifestyle.target_years} years after" if lifestyle.target_years else None, #몇년후로 가고 싶은지
            "images": {
                "original_image_url": lifestyle.original_image_url,  # 원본 이미지 경로
                "generated_image_url": lifestyle.generated_image_url  # 생성된 이미지 경로
            }

        }
        
        # 디버깅: 변환된 데이터 출력
        import json
        print(f"📊 [변환된 데이터] {json.dumps(result, indent=2, ensure_ascii=False, default=str)}")
        
        return result
    except OperationalError as e:
        # DB 연결 실패 시 시스템을 다운시키지 않고 에러 맥락을 반환
        return {
            "error": "Database Connection Failed",
            "message": "현재 데이터베이스 서버에 접속할 수 없습니다. Docker 컨테이너 상태를 확인하세요.",
            "details": str(e)
        }

    except Exception as e:
        return {"error": f"Database query failed: {str(e)}"}
    finally:
        db.close() #세션 반납

if __name__ == "__main__":
    #테스트용
    test_user_id=1
    print(f"Fetching aging context for user_id={test_user_id}")
    result=fetch_user_aging_context(test_user_id)

    import json
    print(json.dumps(result, indent=4, ensure_ascii=False))