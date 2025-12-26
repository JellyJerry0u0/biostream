import time
from fastapi import FastAPI
from sqlalchemy.exc import OperationalError
from .database import engine
from . import models

from .api import auth

app = FastAPI()

# DB 테이블 생성 로직에 재시도 추가
def init_db():
    retries = 5
    while retries > 0:
        try:
            models.Base.metadata.create_all(bind=engine)
            print("Successfully connected to the database and created tables!")
            return
        except OperationalError as e:
            retries -= 1
            print(f"Database not ready yet... {retries} retries left. Error: {e}")
            time.sleep(5)  # 5초 대기 후 다시 시도
    print("Could not connect to the database. Exiting.")

init_db()

app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
@app.get("/")
def read_root():
    return {"status": "ok", "message": "BioStream API is running"}