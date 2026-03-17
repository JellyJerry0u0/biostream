import os
import sys
import time
from pathlib import Path
from fastapi import APIRouter, Depends, Header, HTTPException, UploadFile, File, Form
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
from datetime import date
import json

from app.database import get_db
from app import models
from app.auth.security import verify_token

from app.services.image_service import image_service

# MCP tools 함수 import (MCP 서버의 함수를 사용)
try:
    # 컨테이너 환경에서 MCP 서버의 tools 모듈 import
    # PYTHONPATH가 /app으로 설정되어 있으므로 mcp_server.tools.db_tools로 import 가능
    from mcp_server.tools.db_tools import fetch_user_aging_context
    print("✅ MCP 서버의 fetch_user_aging_context 함수를 import했습니다.")
    MCP_TOOLS_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ MCP 서버의 db_tools를 import할 수 없습니다: {e}")
    print("⚠️ 경로 문제일 수 있으므로 sys.path를 확인합니다.")
    
    # Fallback: 직접 경로 추가
    import sys
    import os
    mcp_server_path = os.path.join(os.path.dirname(__file__), "../../mcp_server")
    mcp_server_path = os.path.abspath(mcp_server_path)
    if mcp_server_path not in sys.path:
        sys.path.insert(0, mcp_server_path)
    
    try:
        from tools.db_tools import fetch_user_aging_context
        print("✅ Fallback 경로로 MCP 서버의 fetch_user_aging_context 함수를 import했습니다.")
        MCP_TOOLS_AVAILABLE = True
    except ImportError as e2:
        print(f"❌ MCP 서버의 함수를 import할 수 없습니다: {e2}")
        MCP_TOOLS_AVAILABLE = False
        raise ImportError("MCP 서버의 db_tools를 사용할 수 없습니다. MCP 서버가 올바르게 설정되었는지 확인하세요.")

router = APIRouter()

# 업로드 디렉터리(프로젝트 상대 경로)
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)


def get_current_user(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
) -> models.User:
    if not authorization:
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")

    token = authorization.replace("Bearer ", "").strip()
    email = verify_token(token)
    if not email:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")

    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="사용자를 찾을 수 없습니다.")
    return user

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
async def collect_data(
    payload: HealthPayload,
    current_user: models.User = Depends(get_current_user),
):
    # 여기서 데이터를 확인합니다.
    print(
        f"📥 수신된 데이터 - 사용자: {current_user.id} "
        f"(payload user_id={payload.user_id}), 지표 수: {len(payload.metrics)}"
    )
    
    # TODO: 여기서 kafka_producer를 통해 Kafka 토픽으로 전송하는 로직이 들어갑니다.
    # producer.send('biometrics', value=payload.dict())

    # 상위 3개 데이터만 상세 출력 (너무 많을 수 있으므로)
    for i, metric in enumerate(payload.metrics[:3]):
        print(f"  [{i+1}] 타입: {metric.type} | 값: {metric.value} {metric.unit}")
        print(f"      기간: {metric.from_date} ~ {metric.to_date}")
    
    if len(payload.metrics) > 3:
        print(f"  ... 외 {len(payload.metrics) - 3}개의 데이터 생략")
    print("="*50 + "\n")
    
    return {"status": "success", "message": f"{len(payload.metrics)}개의 데이터가 전송되었습니다."}

# [3] 이미지 업로드 엔드포인트
@router.post("/upload")
async def upload_image(
    target_years: int = Form(...),
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    이미지 업로드 엔드포인트
    - target_years: 몇 년 후 모습을 보고 싶은지 (연수)
    - file: 업로드할 이미지 파일
    """
    try:
        original_name = Path(file.filename or "upload.bin").name
        print(
            f"📤 이미지 업로드 요청 - user_id: {current_user.id}, "
            f"target_years: {target_years}, filename: {original_name}"
        )
        
        # 1. 파일을 디스크에 저장
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        safe_name = f"{timestamp}_{original_name}"
        save_path = os.path.join(UPLOAD_DIR, safe_name)
        
        contents = await file.read()
        with open(save_path, "wb") as f:
            f.write(contents)
        
        print(f"✅ 파일 저장 완료: {save_path}")
        
        # 2. DB에 Lifestyle 레코드 생성 (원본 이미지 경로 저장)
        # 새로운 모델 구조에 맞게 최소한의 필드만 설정 (나머지는 설문에서 채워짐)
        lifestyle = models.Lifestyle(
            user_id=current_user.id,
            original_image_url=save_path,  # 저장된 파일 경로
            target_years=target_years,
            # 나머지 필드들은 모두 nullable이므로 None으로 설정 (설문에서 채워짐)
        )
        db.add(lifestyle)
        db.commit()
        db.refresh(lifestyle)
        
        print(f"✅ Lifestyle 레코드 생성 완료 - lifestyle_id: {lifestyle.id}")
        
        return {
            "message": "Image uploaded successfully",
            "filename": original_name,
            "saved_path": save_path,
            "lifestyle_id": lifestyle.id,
            "user_id": current_user.id,
            "target_years": target_years
        }
    except Exception as e:
        db.rollback()
        print(f"❌ 이미지 업로드 오류: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Upload error: {str(e)}")

# [4] 사용자 lifestyle 데이터 조회 엔드포인트 (MCP tool 호출)
@router.get("/lifestyle")
async def get_lifestyle_data(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    현재 사용자의 최신 lifestyle 데이터를 조회합니다.
    MCP tool을 사용하여 DB에서 데이터를 가져옵니다.
    """
    try:
        # 인증 확인
        if not authorization:
            raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")
        
        token = authorization.replace("Bearer ", "")
        email = verify_token(token)
        if not email:
            raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
        
        user = db.query(models.User).filter(models.User.email == email).first()
        if not user:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
        
        # MCP tool 함수를 통해 lifestyle 데이터 조회
        # MCP 서버의 fetch_user_aging_context는 자체 DB 세션을 생성하므로 db 파라미터 불필요
        if not MCP_TOOLS_AVAILABLE:
            raise HTTPException(status_code=500, detail="MCP 서버 도구를 사용할 수 없습니다.")
        
        print(f"🔍 MCP 서버를 통해 사용자 {user.id}의 데이터를 조회합니다...")
        lifestyle_data = fetch_user_aging_context(user.id)
        print(f"✅ MCP 서버에서 데이터 조회 완료")
        
        if "error" in lifestyle_data:
            raise HTTPException(status_code=404, detail=lifestyle_data.get("error", "데이터를 찾을 수 없습니다."))
        
        # 이미지 경로를 서버 URL로 변환
        if "images" in lifestyle_data:
            origin = os.getenv("API_BASE_ORIGIN", "http://localhost:8080")
            if lifestyle_data["images"].get("original_image_url"):
                original_path = lifestyle_data["images"]["original_image_url"]
                # 로컬 파일 경로인 경우 서버 URL로 변환
                if os.path.exists(original_path) and UPLOAD_DIR in original_path:
                    relative_path = os.path.relpath(original_path, UPLOAD_DIR)
                    lifestyle_data["images"]["original_image_url"] = f"{origin}/data/image/{relative_path}"
            
            if lifestyle_data["images"].get("generated_image_url"):
                generated_path = lifestyle_data["images"]["generated_image_url"]
                if generated_path and os.path.exists(generated_path) and UPLOAD_DIR in generated_path:
                    relative_path = os.path.relpath(generated_path, UPLOAD_DIR)
                    lifestyle_data["images"]["generated_image_url"] = f"{origin}/data/image/{relative_path}"
        
        return {
            "success": True,
            "data": lifestyle_data
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Lifestyle 데이터 조회 오류: {str(e)}")
        raise HTTPException(status_code=500, detail=f"데이터 조회 실패: {str(e)}")

# [5] 이미지 파일 제공 엔드포인트
@router.get("/image/{file_path:path}")
async def get_image(
    file_path: str,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    업로드된 이미지 파일을 제공합니다.
    file_path는 업로드 디렉터리 내의 상대 경로입니다.
    """
    try:
        # 보안: 파일 경로 검증
        if ".." in file_path or file_path.startswith("/"):
            raise HTTPException(status_code=400, detail="Invalid file path")
        
        # 파일 경로 구성
        image_path = os.path.join(UPLOAD_DIR, file_path)
        image_real_path = os.path.realpath(image_path)
        upload_real_path = os.path.realpath(UPLOAD_DIR)
        if not image_real_path.startswith(upload_real_path + os.sep):
            raise HTTPException(status_code=400, detail="Invalid file path")
        
        # 파일 존재 확인
        if not os.path.exists(image_real_path) or not os.path.isfile(image_real_path):
            raise HTTPException(status_code=404, detail="Image not found")

        # 소유권 검증: lifestyle 이미지 또는 profile 이미지 중 본인 것만 허용
        profile = db.query(models.UserProfile).filter(
            models.UserProfile.user_id == current_user.id,
            models.UserProfile.profile_image_url == image_real_path,
        ).first()
        lifestyle = db.query(models.Lifestyle).filter(
            models.Lifestyle.user_id == current_user.id,
            or_(
                models.Lifestyle.original_image_url == image_real_path,
                models.Lifestyle.generated_image_url == image_real_path,
            ),
        ).first()
        if not profile and not lifestyle:
            raise HTTPException(status_code=404, detail="Image not found")
        
        # 파일 확장자 확인
        ext = os.path.splitext(image_real_path)[1].lower()
        media_type = None
        if ext in ['.jpg', '.jpeg']:
            media_type = 'image/jpeg'
        elif ext == '.png':
            media_type = 'image/png'
        elif ext == '.gif':
            media_type = 'image/gif'
        elif ext == '.webp':
            media_type = 'image/webp'
        else:
            media_type = 'application/octet-stream'
        
        return FileResponse(image_real_path, media_type=media_type)
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ 이미지 제공 오류: {str(e)}")
        raise HTTPException(status_code=500, detail=f"이미지 제공 실패: {str(e)}")

@router.post("/generate-aging/{lifestyle_id}")
async def generate_aging_image(
    lifestyle_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    노화 이미지 생성 API
    """
    lifestyle = db.query(models.Lifestyle).filter(
        models.Lifestyle.id == lifestyle_id,
        models.Lifestyle.user_id == current_user.id,
    ).first()
    if not lifestyle:
        raise HTTPException(status_code=404, detail="Lifestyle not found")

    result = await image_service.request_aging_simulation(
        db=db,
        lifestyle_id=lifestyle_id,
        user_id=current_user.id,
    )

    return result