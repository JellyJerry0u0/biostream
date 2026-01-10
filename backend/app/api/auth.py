#사용자의 요청을 받아 DB에 저장하고 인증 토큰을 발급하는 

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User
from app.auth.security import hash_password, verify_password, create_access_token
from pydantic import BaseModel, EmailStr
from datetime import date

router = APIRouter()

# 입력을 위한 데이터 모델
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    nickname: str
    birthdate: str  # "YYYY-MM-DD" 형식 (필수)
    gender: str  # "남성", "여성", "기타" 등 (필수)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class KakaoLogin(BaseModel):
    kakao_id: str
    email: str
    nickname: str


# 1. 회원가입 API
@router.post("/signup")
def signup(user_in: UserCreate, db: Session = Depends(get_db)):
    # 이미 존재하는 이메일인지 확인
    existing_user = db.query(User).filter(User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 가입된 이메일입니다.")
    
    # 생년월일 파싱 (YYYY-MM-DD 형식, 필수)
    try:
        birthdate_obj = date.fromisoformat(user_in.birthdate)
    except (ValueError, TypeError) as e:
        raise HTTPException(status_code=400, detail=f"생년월일 형식이 올바르지 않습니다. (YYYY-MM-DD): {str(e)}")
    
    # 성별 유효성 검사 (필수)
    if not user_in.gender or user_in.gender.strip() == "":
        raise HTTPException(status_code=400, detail="성별을 선택해주세요.")
    
    # 새 유저 생성 (비밀번호는 반드시 해싱해서 저장)
    new_user = User(
        email=user_in.email,
        hashed_password=hash_password(user_in.password),
        nickname=user_in.nickname,
        birthdate=birthdate_obj,
        gender=user_in.gender
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "회원가입 성공", "user_id": new_user.id}

# 2. 로그인 API (토큰 발급)
@router.post("/login")
def login(user_in: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == user_in.email).first()
    if not user or not verify_password(user_in.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="이메일 또는 비밀번호가 틀렸습니다.")
    
    # 로그인 성공 시 토큰 발급
    token = create_access_token(data={"sub": user.email})
    return {"access_token": token, "token_type": "bearer", "nickname": user.nickname}

# 3. 카카오 로그인 API
@router.post("/kakao-login")
def kakao_login(user_in: KakaoLogin, db: Session = Depends(get_db)):
    # 1. 카카오 ID로 기존 유저 확인
    user = db.query(User).filter(User.kakao_id == user_in.kakao_id).first()
    
    if not user:
        # 2. 카카오 ID는 없지만 이메일이 같은 유저가 있는지 확인 (계정 통합 로직)
        user = db.query(User).filter(User.email == user_in.email).first()
        if user:
            user.kakao_id = user_in.kakao_id # 계정 연결
        else:
            # 3. 아예 새로운 유저라면 생성
            user = User(
                email=user_in.email,
                nickname=user_in.nickname,
                kakao_id=user_in.kakao_id,
                hashed_password=None # 소셜 가입자는 비밀번호 없음
            )
            db.add(user)
        db.commit()
        db.refresh(user)

    # 4. 우리 서비스 전용 JWT 토큰 발급
    token = create_access_token(data={"sub": user.email})
    return {"access_token": token, "token_type": "bearer", "nickname": user.nickname}