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
            
            conn.commit()
            print("✅ 마이그레이션 완료!")
            
        except Exception as e:
            conn.rollback()
            print(f"❌ 마이그레이션 실패: {e}")
            raise

if __name__ == "__main__":
    migrate()
