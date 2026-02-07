"""
기존 로그인 시스템과 보안 모듈 통합 예시

backend/api/auth.py를 이렇게 수정하면 됩니다.
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
import sys
from pathlib import Path

# MCP 보안 모듈 import
mcp_server_path = Path(__file__).parent.parent / "mcp_server"
sys.path.insert(0, str(mcp_server_path))

from security.auth import (
    SecurityManager, 
    PasswordManager, 
    UserRole, 
    Permission
)

# 환경 변수에서 시크릿 키 가져오기
import os
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")

# 보안 관리자 초기화
security_manager = SecurityManager(secret_key=SECRET_KEY)
password_manager = PasswordManager()

router = APIRouter()

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    nickname: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    email: str
    role: str

# 의존성: 데이터베이스 세션 가져오기
def get_db():
    # TODO: 실제 DB 세션 반환
    pass

@router.post("/register")
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    """
    회원가입
    1. 비밀번호 해싱
    2. DB에 사용자 저장
    """
    try:
        # 1. 이메일 중복 확인
        # existing_user = db.query(User).filter(User.email == req.email).first()
        # if existing_user:
        #     raise HTTPException(status_code=400, detail="Email already registered")
        
        # 2. 비밀번호 해싱
        hashed_password = password_manager.hash_password(req.password)
        
        # 3. 사용자 생성
        # new_user = User(
        #     email=req.email,
        #     hashed_password=hashed_password,
        #     nickname=req.nickname,
        # )
        # db.add(new_user)
        # db.commit()
        # db.refresh(new_user)
        
        return {
            "message": "User registered successfully",
            "email": req.email,
            # "user_id": new_user.id
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/login", response_model=LoginResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    """
    로그인
    1. 사용자 확인
    2. 비밀번호 검증
    3. JWT 토큰 생성
    """
    try:
        # 1. 데이터베이스에서 사용자 조회
        # user = db.query(User).filter(User.email == req.email).first()
        # if not user:
        #     raise HTTPException(status_code=401, detail="Invalid credentials")
        
        # 2. 비밀번호 검증
        # if not password_manager.verify_password(req.password, user.hashed_password):
        #     raise HTTPException(status_code=401, detail="Invalid credentials")
        
        # 3. 사용자 역할 결정 (실제로는 DB에서 가져오거나 로직으로 판단)
        user_role = UserRole.FREE  # 기본값
        # if user.subscription_type == "premium":
        #     user_role = UserRole.PREMIUM
        # elif user.is_admin:
        #     user_role = UserRole.ADMIN
        
        # 4. JWT 토큰 생성 (보안 모듈 사용)
        access_token = security_manager.token_validator.create_access_token(
            user_id=str(123),  # user.id
            email=req.email,  # user.email
            role=user_role,
            permissions=None,  # None이면 역할의 기본 권한 사용
            attributes={
                "login_time": "2026-02-07T10:00:00Z",
                "login_ip": "127.0.0.1",  # 실제로는 request.client.host 사용
            }
        )
        
        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            user_id=123,  # user.id
            email=req.email,  # user.email
            role=user_role.value
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/logout")
def logout(token: str):
    """
    로그아웃 (토큰 폐기)
    """
    try:
        # 토큰 검증 후 JTI 추출
        token_payload = security_manager.token_validator.validate_token(token)
        
        # 토큰 폐기
        security_manager.token_validator.revoke_token(token_payload.jti)
        
        return {"message": "Logged out successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=400, detail="Invalid token")

# ==================== 보호된 라우트 예시 ====================

from fastapi import Header

async def get_current_user(authorization: str = Header(...)):
    """
    현재 로그인한 사용자 정보 가져오기
    모든 보호된 라우트에서 이 의존성을 사용
    """
    try:
        # "Bearer <token>" 형식에서 토큰 추출
        if not authorization.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Invalid authorization header")
        
        token = authorization.split("Bearer ")[1]
        
        # 토큰 검증
        token_payload = security_manager.token_validator.validate_token(token)
        
        return {
            "user_id": token_payload.sub,
            "email": token_payload.email,
            "role": token_payload.role,
            "permissions": token_payload.permissions,
        }
        
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

@router.get("/me")
async def get_me(current_user = Depends(get_current_user)):
    """
    현재 로그인한 사용자 정보 반환
    """
    return current_user

@router.get("/protected-data")
async def get_protected_data(current_user = Depends(get_current_user)):
    """
    보호된 데이터 접근 예시
    """
    # 권한 확인
    if Permission.HEALTH_READ.value not in current_user["permissions"]:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    
    return {
        "data": "This is protected health data",
        "user_id": current_user["user_id"]
    }
