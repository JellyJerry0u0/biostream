import os
import time
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from fastapi.responses import JSONResponse
from typing import Optional
from sqlalchemy.orm import Session

from ..database import get_db
from .. import models

router = APIRouter()

# 업로드 디렉터리(프로젝트 상대 경로)
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload")
async def upload_image(
    user_id: int = Form(...),
    target_years: int = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    이미지 업로드 엔드포인트
    - user_id: 사용자 ID
    - target_years: 몇 년 후 모습을 보고 싶은지 (연수)
    - file: 업로드할 이미지 파일
    """
    try:
        # 1. 파일을 디스크에 저장
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        safe_name = f"{timestamp}_{file.filename}"
        save_path = os.path.join(UPLOAD_DIR, safe_name)
        
        contents = await file.read()
        with open(save_path, "wb") as f:
            f.write(contents)
        
        # 2. DB에 Lifestyle 레코드 생성 (원본 이미지 경로 저장)
        lifestyle = models.Lifestyle(
            user_id=user_id,
            original_image_url=save_path,  # 저장된 파일 경로
            target_years=target_years,
            # 필수 필드들은 기본값 또는 NULL로 설정 (나중에 설문에서 채워짐)
            smoking_status="unknown",
            exercise_daily_mins=0,
            exercise_freq_per_week=0,
            exercise_intensity="unknown",
            exercise_type="unknown",
            sedentary_hours_per_day=0.0,
            exercise_regularity="unknown",
            exercise_duration_years=0,
            stretching_habit=False,
            sleep_hours=7.0,
            sleep_quality="good",
            sleep_disorders="none",
            sleep_consistency="regular",
            drinking_frequency="none",
            facial_flushing=False,
            drinking_duration_years=0,
            uv_actuvity_hours=[],
            sunscreen_usage="none",
            sunscreen_reapply_interval="none",
        )
        db.add(lifestyle)
        db.commit()
        db.refresh(lifestyle)
        
        return {
            "message": "Image uploaded successfully",
            "filename": file.filename,
            "saved_path": save_path,
            "lifestyle_id": lifestyle.id,
            "user_id": user_id,
            "target_years": target_years
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Upload error: {str(e)}")

@router.post("/survey")
async def submit_survey(
    lifestyle_id: int = Form(...),
    user_id: int = Form(...),
    target_years: int = Form(...),
    db: Session = Depends(get_db)
):
    """
    설문 데이터 제출 (플레이스홀더 - 나중에 모든 필드 추가)
    """
    try:
        lifestyle = db.query(models.Lifestyle).filter(models.Lifestyle.id == lifestyle_id).first()
        if not lifestyle:
            raise HTTPException(status_code=404, detail="Lifestyle record not found")
        
        # 여기서 설문 데이터를 lifestyle에 업데이트
        # TODO: 나중에 모든 필드 추가
        db.commit()
        
        return {"status": "received", "lifestyle_id": lifestyle_id, "user_id": user_id}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Survey error: {str(e)}")
