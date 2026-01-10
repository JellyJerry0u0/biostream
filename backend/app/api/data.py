import os
import time
from fastapi import APIRouter, Depends, Header, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from typing import List
from sqlalchemy.orm import Session
import json

from app.database import get_db
from app import models

router = APIRouter()

# 업로드 디렉터리(프로젝트 상대 경로)
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# [1] 데이터 규격 정의 (Flutter의 HealthDataPayload와 일치해야 함)
class HealthMetric(BaseModel):
    type: str
    value: str
    unit: str
    from_date: str
    to_date: str

class HealthPayload(BaseModel):
    user_id: str
    metrics: List[HealthMetric]
    timestamp: str

# [2] 데이터 수집 엔드포인트
@router.post("/collect")
async def collect_data(payload: HealthPayload):
    # 여기서 데이터를 확인합니다.
    print(f"📥 수신된 데이터 - 사용자: {payload.user_id}, 지표 수: {len(payload.metrics)}")
    
    # TODO: 여기서 kafka_producer를 통해 Kafka 토픽으로 전송하는 로직이 들어갑니다.
    # producer.send('biometrics', value=payload.dict())

    # 상위 3개 데이터만 상세 출력 (너무 많을 수 있으므로)
    for i, metric in enumerate(payload.metrics[:3]):
        print(f"  [{i+1}] 타입: {metric.type} | 값: {metric.value} {metric.unit}")
        print(f"      기간: {metric.from_date} ~ {metric.to_date}")
    
    if len(payload.metrics) > 3:
        print(f"  ... 외 {len(payload.metrics) - 3}개의 데이터 생략")
    print("="*50 + "\n")
    
    return {"status": "success", "message": f"{len(payload.metrics)}개의 데이터가 Kafka로 전송되었습니다."}

# [3] 이미지 업로드 엔드포인트
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
        print(f"📤 이미지 업로드 요청 - user_id: {user_id}, target_years: {target_years}, filename: {file.filename}")
        
        # 1. 파일을 디스크에 저장
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        safe_name = f"{timestamp}_{file.filename}"
        save_path = os.path.join(UPLOAD_DIR, safe_name)
        
        contents = await file.read()
        with open(save_path, "wb") as f:
            f.write(contents)
        
        print(f"✅ 파일 저장 완료: {save_path}")
        
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
            uv_activity_hours=[],  # 오타 수정: uv_actuvity_hours -> uv_activity_hours
            sunscreen_usage="none",
            sunscreen_reapply_interval="none",
        )
        db.add(lifestyle)
        db.commit()
        db.refresh(lifestyle)
        
        print(f"✅ Lifestyle 레코드 생성 완료 - lifestyle_id: {lifestyle.id}")
        
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
        print(f"❌ 이미지 업로드 오류: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Upload error: {str(e)}")