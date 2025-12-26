#사용자의 요청을 받아 DB에 저장하고 인증 토큰을 발급하는 

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User
from app.auth.security import hash_password, verify_password, create_access_token
from pydantic import BaseModel, EmailStr

router = APIRouter()

# 입력을 위한 데이터 모델
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    nickname: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

# 1. 회원가입 API
@router.post("/signup")
def signup(user_in: UserCreate, db: Session = Depends(get_db)):
    # 이미 존재하는 이메일인지 확인
    existing_user = db.query(User).filter(User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 가입된 이메일입니다.")
    
    # 새 유저 생성 (비밀번호는 반드시 해싱해서 저장)
    new_user = User(
        email=user_in.email,
        hashed_password=hash_password(user_in.password),
        nickname=user_in.nickname
    )
    db.add(new_user)
    db.commit()
    return {"message": "회원가입 성공"}

# 2. 로그인 API (토큰 발급)
@router.post("/login")
def login(user_in: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == user_in.email).first()
    if not user or not verify_password(user_in.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="이메일 또는 비밀번호가 틀렸습니다.")
    
    # 로그인 성공 시 토큰 발급
    token = create_access_token(data={"sub": user.email})
    return {"access_token": token, "token_type": "bearer", "nickname": user.nickname}