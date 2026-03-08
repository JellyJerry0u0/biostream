"""실제 DB 스키마 확인 스크립트"""
import os
from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://myuser:mypassword@localhost:5432/biostream")
engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    for table_name in ["lifestyles", "health_data"]:
        print(f"=== {table_name} 테이블 실제 컬럼 ===\n")
        result = conn.execute(text("""
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns 
            WHERE table_name = :table_name
            ORDER BY ordinal_position
        """), {"table_name": table_name})

        rows = list(result)
        if not rows:
            print(f"⚠️ {table_name} 테이블이 존재하지 않습니다.\n")
            continue

        for row in rows:
            print(f"{row[0]:40} {row[1]:20} NULL={row[2]}")
        print()
