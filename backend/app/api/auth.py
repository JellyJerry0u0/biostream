#사용자의 요청을 받아 DB에 저장하고 인증 토큰을 발급하는 

import os
import time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Header, UploadFile, File, Form
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, UserProfile
from app.auth.security import hash_password, verify_password, create_access_token
from pydantic import BaseModel, EmailStr
from datetime import date

router = APIRouter()

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)


def _get_user_from_auth(authorization: Optional[str], db: Session) -> User:
    if not authorization:
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")

    token = authorization.replace("Bearer ", "")
    from app.auth.security import verify_token

    email = verify_token(token)
    if not email:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return user

# 입력을 위한 데이터 모델
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    nickname: str
    birthdate: str  # "YYYY-MM-DD" 형식 (필수)
    gender: str  # "남성", "여성", "기타" 등 (필수)
    is_pregnant: bool = None  # 임신 여부 (여성일 경우에만 선택 가능, 선택)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class KakaoLogin(BaseModel):
    kakao_id: str
    email: str
    nickname: str
    birthdate: str = None  # "YYYY-MM-DD" 형식 (선택)
    gender: str = None  # "남성", "여성", "기타" 등 (선택)


# 1. 회원가입 API
@router.post("/signup")
def signup(user_in: UserCreate, db: Session = Depends(get_db)):
    print(f"📝 회원가입 요청 - Email: {user_in.email}, Nickname: {user_in.nickname}")
    print(f"   Birthdate: {user_in.birthdate}, Gender: {user_in.gender}")
    
    # 이미 존재하는 이메일인지 확인
    existing_user = db.query(User).filter(User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 가입된 이메일입니다.")
    
    # 생년월일 파싱 (YYYY-MM-DD 형식, 필수)
    try:
        birthdate_obj = date.fromisoformat(user_in.birthdate)
        print(f"✅ 생년월일 파싱 성공: {birthdate_obj}")
    except (ValueError, TypeError) as e:
        print(f"❌ 생년월일 파싱 실패: {str(e)}")
        raise HTTPException(status_code=400, detail=f"생년월일 형식이 올바르지 않습니다. (YYYY-MM-DD): {str(e)}")
    
    # 성별 유효성 검사 (필수)
    if not user_in.gender or user_in.gender.strip() == "":
        print(f"❌ 성별이 비어있음")
        raise HTTPException(status_code=400, detail="성별을 선택해주세요.")
    
    # 임신 여부 유효성 검사: 여성이 아닐 경우 임신 여부는 무시 (null로 설정)
    is_pregnant_value = None
    if user_in.gender == "여성":
        is_pregnant_value = user_in.is_pregnant if user_in.is_pregnant is not None else None
    else:
        # 여성이 아닌 경우 임신 여부는 항상 null
        if user_in.is_pregnant is not None:
            print(f"⚠️  여성이 아닌데 임신 여부 값이 전달됨. 무시하고 null로 설정합니다.")
        is_pregnant_value = None
    
    # 나이 계산 (로그용)
    today = date.today()
    calculated_age = today.year - birthdate_obj.year - ((today.month, today.day) < (birthdate_obj.month, birthdate_obj.day))
    print(f"📊 계산된 나이: {calculated_age}세")
    
    # 새 유저 생성 (비밀번호는 반드시 해싱해서 저장)
    new_user = User(
        email=user_in.email,
        hashed_password=hash_password(user_in.password),
        nickname=user_in.nickname,
        birthdate=birthdate_obj,
        gender=user_in.gender,
        is_pregnant=is_pregnant_value
    )
    db.add(new_user)
    
    try:
        db.commit()
        db.refresh(new_user)
        print(f"✅ 회원가입 성공 - User ID: {new_user.id}, Birthdate: {new_user.birthdate}, Gender: {new_user.gender}")
        return {"message": "회원가입 성공", "user_id": new_user.id, "calculated_age": calculated_age}
    except Exception as e:
        db.rollback()
        print(f"❌ DB 저장 실패: {str(e)}")
        raise HTTPException(status_code=500, detail=f"회원가입 실패: {str(e)}")

# 2. 로그인 API (토큰 발급)
@router.post("/login")
def login(user_in: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == user_in.email).first()
    if not user or not verify_password(user_in.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="이메일 또는 비밀번호가 틀렸습니다.")
    
    # 로그인 성공 시 토큰 발급
    token = create_access_token(data={"sub": user.email})
    return {
        "access_token": token,
        "token_type": "bearer",
        "nickname": user.nickname,
        "user_id": user.id,
    }

# 3. 카카오 로그인 API
@router.post("/kakao-login")
def kakao_login(user_in: KakaoLogin, db: Session = Depends(get_db)):
    # 1. 카카오 ID로 기존 유저 확인
    user = db.query(User).filter(User.kakao_id == user_in.kakao_id).first()
    
    if not user:
        # 2. 카카오 ID는 없지만 이메일이 같은 유저가 있는지 확인 (계정 통합 로직)
        user = db.query(User).filter(User.email == user_in.email).first()
        if user:
            user.kakao_id = user_in.kakao_id  # 계정 연결
            # 기존 유저인데 birthdate/gender가 없으면 업데이트
            if user_in.birthdate and not user.birthdate:
                try:
                    user.birthdate = date.fromisoformat(user_in.birthdate)
                except (ValueError, TypeError):
                    pass  # 형식 오류는 무시
            if user_in.gender and not user.gender:
                user.gender = user_in.gender
        else:
            # 3. 아예 새로운 유저라면 생성
            birthdate_obj = None
            if user_in.birthdate:
                try:
                    birthdate_obj = date.fromisoformat(user_in.birthdate)
                except (ValueError, TypeError):
                    pass  # 형식 오류는 무시하고 None으로 둠
            
            user = User(
                email=user_in.email,
                nickname=user_in.nickname,
                kakao_id=user_in.kakao_id,
                hashed_password=None,  # 소셜 가입자는 비밀번호 없음
                birthdate=birthdate_obj,
                gender=user_in.gender
            )
            db.add(user)
        db.commit()
        db.refresh(user)

    # 4. 우리 서비스 전용 JWT 토큰 발급
    token = create_access_token(data={"sub": user.email})
    return {"access_token": token, "token_type": "bearer", "nickname": user.nickname}


@router.get("/me")
def get_my_profile(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    user = _get_user_from_auth(authorization, db)
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()

    image_url = None
    if profile and profile.profile_image_url:
        raw_path = profile.profile_image_url
        origin = os.getenv("API_BASE_ORIGIN", "http://localhost:8080")
        if os.path.exists(raw_path) and UPLOAD_DIR in raw_path:
            relative_path = os.path.relpath(raw_path, UPLOAD_DIR)
            image_url = f"{origin}/data/image/{relative_path}"
        else:
            image_url = raw_path

    return {
        "email": user.email,
        "nickname": user.nickname,
        "profile_image_url": image_url,
    }


@router.put("/me")
async def update_my_profile(
    nickname: str = Form(...),
    email: EmailStr = Form(...),
    profile_image: Optional[UploadFile] = File(None),
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    user = _get_user_from_auth(authorization, db)

    existing_user = db.query(User).filter(User.email == email, User.id != user.id).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 사용 중인 이메일입니다.")

    user.nickname = nickname
    user.email = email

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    if not profile:
        profile = UserProfile(user_id=user.id)
        db.add(profile)

    if profile_image is not None:
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        safe_name = f"profile_{user.id}_{timestamp}_{profile_image.filename}"
        save_path = os.path.join(UPLOAD_DIR, safe_name)
        contents = await profile_image.read()
        with open(save_path, "wb") as f:
            f.write(contents)
        profile.profile_image_url = save_path

    db.commit()
    db.refresh(user)
    db.refresh(profile)

    origin = os.getenv("API_BASE_ORIGIN", "http://localhost:8080")
    image_url = None
    if profile.profile_image_url:
        if os.path.exists(profile.profile_image_url) and UPLOAD_DIR in profile.profile_image_url:
            relative_path = os.path.relpath(profile.profile_image_url, UPLOAD_DIR)
            image_url = f"{origin}/data/image/{relative_path}"
        else:
            image_url = profile.profile_image_url

    return {
        "message": "프로필이 업데이트되었습니다.",
        "email": user.email,
        "nickname": user.nickname,
        "profile_image_url": image_url,
    }