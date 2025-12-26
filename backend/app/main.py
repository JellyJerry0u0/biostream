import time
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import OperationalError

from .database import engine, get_db
from . import models
from .api import auth  # 만약 경로 에러가 나면 from app.api import auth로 시도

app = FastAPI(title="BioStream API")

# [1] CORS 설정: 브라우저(Chrome) 테스트를 위해 필수입니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 서비스에서는 특정 도메인만 지정하는 것이 좋습니다.
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# [2] DB 초기화 로직
def init_db():
    retries = 5
    while retries > 0:
        try:
            models.Base.metadata.create_all(bind=engine)
            print("✅ Successfully connected to the database and created tables!")
            return
        except OperationalError as e:
            retries -= 1
            print(f"⚠️ Database not ready... {retries} retries left.")
            time.sleep(5)
    print("❌ Could not connect to the database. Exiting.")

init_db()

# [3] 라우터 등록
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])

@app.get("/")
def read_root():
    return {"status": "ok", "message": "BioStream API is running"}