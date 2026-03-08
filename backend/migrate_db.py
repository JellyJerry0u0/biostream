"""
데이터베이스 마이그레이션 스크립트

Lifestyle 테이블에 health_report 관련 컬럼 추가
"""

import os
from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://myuser:mypassword@localhost:5432/biostream")

engine = create_engine(DATABASE_URL)

def migrate():
    """데이터베이스 마이그레이션 실행"""
    print("🔄 데이터베이스 마이그레이션 시작...")
    
    with engine.connect() as conn:
        try:
            # outcomes 컬럼 추가 (주요 목표)
            conn.execute(text("""
                ALTER TABLE lifestyles 
                ADD COLUMN IF NOT EXISTS outcomes JSON;
            """))
            print("✅ outcomes 컬럼 추가 완료")
            
            # health_report 컬럼 추가
            conn.execute(text("""
                ALTER TABLE lifestyles 
                ADD COLUMN IF NOT EXISTS health_report JSON;
            """))
            print("✅ health_report 컬럼 추가 완료")
            
            # health_report_generated_at 컬럼 추가
            conn.execute(text("""
                ALTER TABLE lifestyles 
                ADD COLUMN IF NOT EXISTS health_report_generated_at TIMESTAMP WITH TIME ZONE;
            """))
            print("✅ health_report_generated_at 컬럼 추가 완료")
            
            # 이미지 생성 관련 컬럼 추가
            conn.execute(text("""
                ALTER TABLE lifestyles 
                ADD COLUMN IF NOT EXISTS generation_status VARCHAR DEFAULT 'not_started';
            """))
            print("✅ generation_status 컬럼 추가 완료")
            
            conn.execute(text("""
                ALTER TABLE lifestyles 
                ADD COLUMN IF NOT EXISTS image_gen_params JSON;
            """))
            print("✅ image_gen_params 컬럼 추가 완료")

            # health_data 테이블 생성 (Health Connect 동기화 데이터 저장)
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS health_data (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id),
                    steps INTEGER NOT NULL DEFAULT 0,
                    sleep_minutes INTEGER NOT NULL DEFAULT 0,
                    distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0,
                    oxygen_saturation DOUBLE PRECISION NOT NULL DEFAULT 0,
                    average_speed_mps DOUBLE PRECISION NOT NULL DEFAULT 0,
                    nutrition_calories_kcal DOUBLE PRECISION NOT NULL DEFAULT 0,
                    exercise_minutes INTEGER NOT NULL DEFAULT 0,
                    fitness_score DOUBLE PRECISION NOT NULL DEFAULT 0,
                    weight_kg DOUBLE PRECISION NOT NULL DEFAULT 0,
                    body_fat_percentage DOUBLE PRECISION NOT NULL DEFAULT 0,
                    vo2_max DOUBLE PRECISION NOT NULL DEFAULT 0,
                    blood_glucose_mg_dl DOUBLE PRECISION NOT NULL DEFAULT 0,
                    sync_date DATE NOT NULL,
                    is_processed BOOLEAN NOT NULL DEFAULT FALSE,
                    notification_sent BOOLEAN NOT NULL DEFAULT FALSE,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE
                );
            """))
            print("✅ health_data 테이블 확인/생성 완료")

            # 기존 DB 대비 health_data 확장 컬럼 보강
            conn.execute(text("""
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS distance_meters DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS oxygen_saturation DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS average_speed_mps DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS nutrition_calories_kcal DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS exercise_minutes INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS fitness_score DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS weight_kg DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS body_fat_percentage DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS vo2_max DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS blood_glucose_mg_dl DOUBLE PRECISION NOT NULL DEFAULT 0;
                ALTER TABLE health_data ADD COLUMN IF NOT EXISTS notification_sent BOOLEAN NOT NULL DEFAULT FALSE;
            """))
            print("✅ health_data 확장 컬럼 보강 완료")

            # 유니크 인덱스 생성 전 중복 데이터 정리 (가장 최신 1건만 유지)
            conn.execute(text("""
                DELETE FROM health_data
                WHERE ctid IN (
                    SELECT ctid FROM (
                        SELECT ctid,
                               ROW_NUMBER() OVER (
                                   PARTITION BY user_id, sync_date
                                   ORDER BY COALESCE(updated_at, created_at) DESC, id DESC
                               ) AS rn
                        FROM health_data
                    ) t
                    WHERE t.rn > 1
                );
            """))
            print("✅ health_data 중복 데이터 정리 완료")

            # 중복 업서트를 위한 유니크 키
            conn.execute(text("""
                CREATE UNIQUE INDEX IF NOT EXISTS uq_health_data_user_sync_date
                ON health_data (user_id, sync_date);
            """))
            print("✅ health_data 유니크 인덱스(user_id, sync_date) 확인/생성 완료")

            # 스케줄러 조회 최적화 인덱스
            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS ix_health_data_is_processed
                ON health_data (is_processed);
            """))
            print("✅ health_data 인덱스(is_processed) 확인/생성 완료")

            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS ix_health_data_notification_sent
                ON health_data (notification_sent);
            """))
            print("✅ health_data 인덱스(notification_sent) 확인/생성 완료")

            # user_device_tokens 테이블 생성 (FCM 디바이스 토큰 저장)
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS user_device_tokens (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    device_token VARCHAR NOT NULL,
                    platform VARCHAR NOT NULL DEFAULT 'android',
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE
                );
            """))
            print("✅ user_device_tokens 테이블 확인/생성 완료")

            conn.execute(text("""
                CREATE UNIQUE INDEX IF NOT EXISTS uq_user_device_tokens_user_token
                ON user_device_tokens (user_id, device_token);
            """))
            print("✅ user_device_tokens 유니크 인덱스(user_id, device_token) 확인/생성 완료")

            conn.execute(text("""
                CREATE INDEX IF NOT EXISTS ix_user_device_tokens_user_id
                ON user_device_tokens (user_id);
            """))
            print("✅ user_device_tokens 인덱스(user_id) 확인/생성 완료")
            
            conn.commit()
            print("✅ 마이그레이션 완료!")
            
        except Exception as e:
            conn.rollback()
            print(f"❌ 마이그레이션 실패: {e}")
            raise

if __name__ == "__main__":
    migrate()
