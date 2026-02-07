"""실제 DB 스키마 확인 스크립트"""
import os
from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://myuser:mypassword@localhost:5432/biostream")
engine = create_engine(DATABASE_URL)

print("=== lifestyles 테이블 실제 컬럼 ===\n")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns 
        WHERE table_name = 'lifestyles' 
        ORDER BY ordinal_position
    """))
    
    for row in result:
        print(f"{row[0]:40} {row[1]:20} NULL={row[2]}")
