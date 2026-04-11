import asyncio
import os
import sys
import time
from pathlib import Path
from fastapi import APIRouter, Depends, Header, HTTPException, Request, UploadFile, File, Form
from fastapi.responses import FileResponse
from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
from datetime import date
import json

from app.database import get_db
from app import models
from app.auth.security import verify_token

from app.services.image_service import image_service
from app.api.public_origin import resolve_public_api_origin


def _gpu_env_hint_for_detail() -> str:
    """사용자/로그에 그대로 붙일 짧은 힌트 (Docker + localhost GPU 오설정)."""
    if os.getenv("RUNNING_IN_DOCKER") != "true":
        return ""
    bu = (image_service.gpu_server_url or "").lower()
    if not bu or ("127.0.0.1" not in bu and "localhost" not in bu):
        return ""
    return (
        " Docker에서는 localhost가 호스트 GPU가 아닙니다. "
        "IMAGE_GENERATION_BASE_URL을 host.docker.internal(또는 공인 GPU URL)로 설정하세요."
    )


def _format_image_gen_error(exc: Exception) -> str:
    msg = str(exc)
    msg += _gpu_env_hint_for_detail()
    return msg


async def _wait_for_lifestyle_generated_url(
    db: Session,
    *,
    lifestyle_id: int,
    user_id: int,
    max_wait_seconds: float = 190.0,
    poll_interval: float = 0.5,
) -> models.Lifestyle:
    """
    페이스스캔에서 먼저 돌린 /generate 가 끝날 때까지 DB만 폴링 (GPU 이중 호출 방지).
    GPU 클라이언트 timeout(180s)에 맞춰 여유를 둔 대기 상한.

    매 주기마다 expire_all() 로 동일 세션에 캐시된 Lifestyle 행을 무효화해,
    병렬 /generate 요청이 커밋한 generated_image_url 을 놓치지 않게 한다.
    """
    deadline = time.monotonic() + max_wait_seconds
    started = time.monotonic()
    while True:
        db.expire_all()
        lifestyle = (
            db.query(models.Lifestyle)
            .filter(
                models.Lifestyle.id == lifestyle_id,
                models.Lifestyle.user_id == user_id,
            )
            .first()
        )
        if not lifestyle:
            raise HTTPException(status_code=404, detail="Lifestyle not found")
        if (lifestyle.generated_image_url or "").strip():
            waited = time.monotonic() - started
            print(
                f"[GPU] skin-edit 대기: generated_image_url 확인됨 "
                f"lifestyle_id={lifestyle_id} waited_s={waited:.2f}"
            )
            return lifestyle
        if time.monotonic() >= deadline:
            waited = time.monotonic() - started
            print(
                f"[GPU] skin-edit 대기: 타임아웃({max_wait_seconds}s)에도 URL 없음 "
                f"lifestyle_id={lifestyle_id} waited_s={waited:.2f} "
                f"→ 폴백 /generate 1회 예정"
            )
            return lifestyle
        await asyncio.sleep(poll_interval)

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

# 이미지 업로드 엔드포인트
@router.post("/upload")
async def upload_image(
    file: UploadFile = File(...),
    target_years: int = Form(default=30),  # 고정값 30 (이미지 생성은 별도로 3 사용)
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    이미지 업로드 엔드포인트
    - file: 업로드할 이미지 파일
    - target_years: DB 저장용 (고정 30), 실제 이미지 생성은 3 사용
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
    request: Request,
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
            origin = resolve_public_api_origin(request)
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
                models.Lifestyle.ideal_habits_skin_image_url == image_real_path,
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


@router.post("/generate/{lifestyle_id}")
async def generate_image_default(
    lifestyle_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    기본 파라미터로 /generate 이미지 생성 요청을 시작합니다.
    """
    lifestyle = db.query(models.Lifestyle).filter(
        models.Lifestyle.id == lifestyle_id,
        models.Lifestyle.user_id == current_user.id,
    ).first()
    if not lifestyle:
        raise HTTPException(status_code=404, detail="Lifestyle not found")

    try:
        result = await image_service.request_generate_image(
            db=db,
            lifestyle_id=lifestyle_id,
            user_id=current_user.id,
        )
        return {
            "success": True,
            "lifestyle_id": lifestyle_id,
            **result,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"기본 이미지 생성 요청 실패: {_format_image_gen_error(e)}",
        )


@router.post("/skin-edit/{lifestyle_id}")
async def skin_edit_generated_image(
    lifestyle_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    /generate 결과 이미지를 입력으로 GPU /skin-edit를 호출합니다.
    습관 기반 6종 점수(0/100)는 라이프스타일에서만 계산해 GPU 폼과 동일하게 전달합니다.
    """
    lifestyle = db.query(models.Lifestyle).filter(
        models.Lifestyle.id == lifestyle_id,
        models.Lifestyle.user_id == current_user.id,
    ).first()
    if not lifestyle:
        raise HTTPException(status_code=404, detail="Lifestyle not found")

    try:
        # 페이스스캔에서 미리 보낸 /generate 가 끝날 때까지 기다린 뒤 skin-edit (중복 generate 방지).
        lifestyle = await _wait_for_lifestyle_generated_url(
            db,
            lifestyle_id=lifestyle_id,
            user_id=current_user.id,
        )
        generate_fallback_after_wait = False
        if not (lifestyle.generated_image_url or "").strip():
            generate_fallback_after_wait = True
            print(
                f"[GPU] skin-edit 폴백: 선행 /generate 없음·실패·대기 초과로 "
                f"서버에서 추가 POST /generate 호출 lifestyle_id={lifestyle_id}"
            )
            await image_service.request_generate_image(
                db=db,
                lifestyle_id=lifestyle_id,
                user_id=current_user.id,
            )

        result = await image_service.request_skin_edit_from_generated(
            db=db,
            lifestyle_id=lifestyle_id,
            user_id=current_user.id,
        )
        return {
            "success": True,
            "lifestyle_id": lifestyle_id,
            "skin_edit_trace": {
                "waited_for_parallel_generate": True,
                "generate_fallback_after_timeout": generate_fallback_after_wait,
                "meaning": "True면 선행 /generate 없음·실패·대기 초과 후 서버가 추가로 /generate 1회 호출함.",
            },
            **result,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"skin-edit 요청 실패: {_format_image_gen_error(e)}",
        )