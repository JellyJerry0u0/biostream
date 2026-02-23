import time
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import OperationalError
from dotenv import load_dotenv
from .database import engine, get_db

from .database import engine, get_db
from . import models
from .api import auth, data, health  # 만약 경로 에러가 나면 from app.api import auth로 시도
from .scheduler import start_scheduler, stop_scheduler

load_dotenv()

app = FastAPI(title="BioStream API")


@app.on_event("startup")
async def startup_event():
    start_scheduler()


@app.on_event("shutdown")
async def shutdown_event():
    stop_scheduler()

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
app.include_router(data.router, prefix="/data", tags=["Data Collection"])
app.include_router(health.router)

# Lifestyle 설문조사 API (Lifestyle 모델 기반)
from .api import lifestyle_survey
app.include_router(lifestyle_survey.router, prefix="/api", tags=["Lifestyle Survey"])

# 건강 리포트 생성 API (Qdrant 중심 RAG + LangGraph 기반)
from .api import report
app.include_router(report.router, prefix="/api", tags=["Health Report"])

# 코치 챗봇 WebSocket (/ws/coach)
from .api import coach_ws
app.include_router(coach_ws.router, tags=["Coach Chatbot"])

@app.get("/")
def read_root():
    return {"status": "ok", "message": "BioStream API is running"}

@app.get("/health")
def health_check():
    """헬스 체크 엔드포인트"""
    return {"status": "healthy", "message": "BioStream API is running"}
