import os
import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
from sqlalchemy import text
from .scheduler import start_scheduler, stop_scheduler

load_dotenv()
from .database import engine

from .api import auth, data, health, notification  # 만약 경로 에러가 나면 from app.api import auth로 시도

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

# [2] 라우터 등록
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(data.router, prefix="/data", tags=["Data Collection"])
app.include_router(health.router)
app.include_router(notification.router)

# Lifestyle 설문조사 API (Lifestyle 모델 기반)
from .api import lifestyle_survey
app.include_router(lifestyle_survey.router, prefix="/api", tags=["Lifestyle Survey"])

# 건강 리포트 생성 API (Qdrant 중심 RAG + LangGraph 기반)
from .api import report
app.include_router(report.router, prefix="/api", tags=["Health Report"])

# 습관 코칭 API
from .api import committed_actions
app.include_router(committed_actions.router)

# 코치 챗봇 WebSocket (/ws/coach)
from .api import coach_ws
app.include_router(coach_ws.router, tags=["Coach Chatbot"])

from .api import coach_agent_api
app.include_router(coach_agent_api.router)

from .api import coach_goals
app.include_router(coach_goals.router)

from .api import coach_inbox
app.include_router(coach_inbox.router)

@app.get("/")
def read_root():
    return {"status": "ok", "message": "BioStream API is running"}

@app.get("/health")
def health_check():
    """헬스 체크 엔드포인트"""
    return {"status": "healthy", "message": "BioStream API is running"}


@app.get("/ready")
def readiness_check():
    """DB/Qdrant 의존성 준비 상태 확인"""
    db_ok = False
    qdrant_ok = False
    qdrant_url = os.getenv("QDRANT_URL", "http://localhost:6333").rstrip("/")

    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    try:
        # Qdrant returns 200 on /collections, while /health may return 404 by version.
        response = httpx.get(f"{qdrant_url}/collections", timeout=2.0)
        qdrant_ok = response.status_code == 200
    except Exception:
        qdrant_ok = False

    if db_ok and qdrant_ok:
        return {"status": "ready", "db": "ok", "qdrant": "ok"}
    return JSONResponse(
        status_code=503,
        content={
            "status": "not_ready",
            "db": "ok" if db_ok else "error",
            "qdrant": "ok" if qdrant_ok else "error",
        },
    )
