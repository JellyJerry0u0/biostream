from fastapi import FastAPI
from .database import engine
from . import models

# 서버 시작 시 SQLAlchemy 모델을 기반으로 DB 테이블 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

@app.get("/")
def root():
    return {"message": "BioStream Database & API are ready!"}