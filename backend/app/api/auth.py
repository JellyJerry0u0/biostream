#사용자의 요청을 받아 DB에 저장하고 인증 토큰을 발급하는

import os
import time
import threading
from collections import defaultdict
from typing import Optional
import httpx

from fastapi import APIRouter, Depends, HTTPException, Header, Request, UploadFile, File, Form
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, UserProfile, Lifestyle
from app.auth.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token,
    verify_token, verify_refresh_token,
)
from pydantic import BaseModel, EmailStr
from datetime import date

from app.api.public_origin import resolve_public_api_origin

router = APIRouter()

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Rate limiter (인메모리, 프로세스 재시작 시 초기화됨)
# ---------------------------------------------------------------------------
_login_attempts: dict[str, list[float]] = defaultdict(list)
_rate_lock = threading.Lock()
_RATE_WINDOW = 60   # 초
_RATE_MAX = 5       # 창(window) 내 최대 시도 횟수

def _check_rate_limit(identifier: str):
    now = time.time()
    with _rate_lock:
        attempts = _login_attempts[identifier]
        attempts[:] = [t for t in attempts if now - t < _RATE_WINDOW]
        if len(attempts) >= _RATE_MAX:
            raise HTTPException(
                status_code=429,
                detail="로그인 시도 횟수를 초과했습니다. 잠시 후 다시 시도해주세요.",
            )
        attempts.append(now)


def get_current_user(authorization: Optional[str] = Header(None), db: Session = Depends(get_db)):
    if not authorization:
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")
    try:
        raw = authorization.strip()
        # Bearer 헤더 파싱 (대소문자 무관)
        if raw.lower().startswith("bearer "):
            token = raw[7:]
        else:
            token = raw
        email = verify_token(token)
        if not email:
            raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(status_code=401, detail="사용자를 찾을 수 없습니다.")
        return user
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="인증 실패")

# 입력을 위한 데이터 모델
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    nickname: str
    birthdate: str  # "YYYY-MM-DD" 형식 (필수)
    gender: str  # "남성", "여성", "기타" 등 (필수)
    is_pregnant: bool = None  # 임신 여부 (여성일 경우에만 선택 가능, 선택)
    smoking_status: Optional[str] = None  # 흡연 여부: never / former / current

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class KakaoLogin(BaseModel):
    access_token: str

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class ProfileUpdate(BaseModel):
    birthdate: str  # "YYYY-MM-DD" 형식 (필수)
    gender: str  # "남성", "여성", "기타" (필수)
    smoking_status: Optional[str] = None  # never / former / current


# 1. 회원가입 API
@router.post("/signup")
def signup(user_in: UserCreate, db: Session = Depends(get_db)):
    print(f"📝 회원가입 요청 - Email: {user_in.email}, Nickname: {user_in.nickname}")
    print(f"   Birthdate: {user_in.birthdate}, Gender: {user_in.gender}")

    # 비밀번호 강도 검증
    if len(user_in.password) < 8:
        raise HTTPException(status_code=400, detail="비밀번호는 8자 이상이어야 합니다.")

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
        if user_in.is_pregnant is not None:
            print(f"⚠️  여성이 아닌데 임신 여부 값이 전달됨. 무시하고 null로 설정합니다.")
        is_pregnant_value = None

    # 나이 계산 (로그용)
    today = date.today()
    calculated_age = today.year - birthdate_obj.year - ((today.month, today.day) < (birthdate_obj.month, birthdate_obj.day))
    print(f"📊 계산된 나이: {calculated_age}세")

    # 흡연 여부: never/former/current (선택, 없으면 None)
    smoking_status_value = None
    if user_in.smoking_status and user_in.smoking_status.strip() in ("never", "former", "current"):
        smoking_status_value = user_in.smoking_status.strip()

    # 새 유저 생성 (비밀번호는 반드시 해싱해서 저장)
    new_user = User(
        email=user_in.email,
        hashed_password=hash_password(user_in.password),
        nickname=user_in.nickname,
        birthdate=birthdate_obj,
        gender=user_in.gender,
        is_pregnant=is_pregnant_value,
        smoking_status=smoking_status_value,
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
def login(user_in: UserLogin, request: Request, db: Session = Depends(get_db)):
    client_ip = request.client.host if request.client else "unknown"
    _check_rate_limit(f"{client_ip}:{user_in.email}")

    user = db.query(User).filter(User.email == user_in.email).first()
    if not user:
        raise HTTPException(status_code=400, detail="이메일 또는 비밀번호가 틀렸습니다.")

    if not user.hashed_password:
        raise HTTPException(status_code=400, detail="소셜 로그인 계정입니다. 카카오 로그인을 이용해주세요.")

    if not verify_password(user_in.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="이메일 또는 비밀번호가 틀렸습니다.")

    # 로그인 성공 시 토큰 발급
    access_token = create_access_token(data={"sub": user.email})
    refresh_token = create_refresh_token(data={"sub": user.email})
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "nickname": user.nickname,
        "user_id": user.id,
    }

# 3. 카카오 로그인 API
async def _fetch_kakao_user_info(access_token: str) -> dict:
    """카카오 액세스 토큰을 서버에서 검증하고 사용자 정보를 가져옵니다."""
    if not access_token or not access_token.strip():
        raise HTTPException(status_code=401, detail="카카오 액세스 토큰이 필요합니다.")

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                "https://kapi.kakao.com/v2/user/me",
                headers={"Authorization": f"Bearer {access_token.strip()}"},
            )
    except httpx.HTTPError:
        raise HTTPException(status_code=401, detail="카카오 토큰 검증에 실패했습니다.")

    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="유효하지 않은 카카오 토큰입니다.")

    payload = response.json()
    kakao_id = payload.get("id")
    if kakao_id is None:
        raise HTTPException(status_code=401, detail="카카오 사용자 식별에 실패했습니다.")

    account = payload.get("kakao_account") or {}
    profile = account.get("profile") or {}

    email = account.get("email") or f"kakao_{kakao_id}@kakao.user"
    nickname = profile.get("nickname") or "카카오사용자"

    birthdate = None
    birthyear = account.get("birthyear")
    birthday = account.get("birthday")  # MMDD
    if birthyear and birthday and isinstance(birthday, str) and len(birthday) == 4:
        birthdate = f"{birthyear}-{birthday[:2]}-{birthday[2:]}"
    elif birthyear:
        birthdate = f"{birthyear}-01-01"

    gender_raw = account.get("gender")
    gender = None
    if isinstance(gender_raw, str):
        if gender_raw.lower() == "male":
            gender = "남성"
        elif gender_raw.lower() == "female":
            gender = "여성"
        else:
            gender = "기타"

    return {
        "kakao_id": str(kakao_id),
        "email": email,
        "nickname": nickname,
        "birthdate": birthdate,
        "gender": gender,
    }


@router.post("/kakao-login")
async def kakao_login(user_in: KakaoLogin, db: Session = Depends(get_db)):
    verified = await _fetch_kakao_user_info(user_in.access_token)

    # 1. 카카오 ID로 기존 유저 확인
    user = db.query(User).filter(User.kakao_id == verified["kakao_id"]).first()

    if not user:
        # 2. 카카오 ID는 없지만 이메일이 같은 유저가 있는지 확인 (계정 통합 로직)
        user = db.query(User).filter(User.email == verified["email"]).first()
        if user:
            user.kakao_id = verified["kakao_id"]  # 계정 연결
            if verified["birthdate"] and not user.birthdate:
                try:
                    user.birthdate = date.fromisoformat(verified["birthdate"])
                except (ValueError, TypeError):
                    pass
            if verified["gender"] and not user.gender:
                user.gender = verified["gender"]
        else:
            # 3. 아예 새로운 유저라면 생성
            birthdate_obj = None
            if verified["birthdate"]:
                try:
                    birthdate_obj = date.fromisoformat(verified["birthdate"])
                except (ValueError, TypeError):
                    pass

            user = User(
                email=verified["email"],
                nickname=verified["nickname"],
                kakao_id=verified["kakao_id"],
                hashed_password=None,  # 소셜 가입자는 비밀번호 없음
                birthdate=birthdate_obj,
                gender=verified["gender"],
            )
            db.add(user)
        db.commit()
        db.refresh(user)

    # 4. 우리 서비스 전용 JWT 토큰 발급
    access_token = create_access_token(data={"sub": user.email})
    refresh_token = create_refresh_token(data={"sub": user.email})
    needs_profile = user.birthdate is None or user.gender is None
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "email": user.email,
        "nickname": user.nickname,
        "user_id": user.id,
        "needs_profile": needs_profile,
    }


# 5. 토큰 갱신 API
@router.post("/refresh")
def refresh_token(body: RefreshTokenRequest, db: Session = Depends(get_db)):
    email = verify_refresh_token(body.refresh_token)
    if not email:
        raise HTTPException(status_code=401, detail="유효하지 않거나 만료된 리프레시 토큰입니다.")
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="사용자를 찾을 수 없습니다.")
    new_access_token = create_access_token(data={"sub": user.email})
    return {"access_token": new_access_token, "token_type": "bearer"}


def _latest_lifestyle(db: Session, user_id: int) -> Optional[Lifestyle]:
    return (
        db.query(Lifestyle)
        .filter(Lifestyle.user_id == user_id)
        .order_by(Lifestyle.created_at.desc())
        .first()
    )


@router.get("/me")
def get_my_profile(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()

    image_url = None
    if profile and profile.profile_image_url:
        raw_path = profile.profile_image_url
        origin = resolve_public_api_origin(request)
        if os.path.exists(raw_path) and UPLOAD_DIR in raw_path:
            relative_path = os.path.relpath(raw_path, UPLOAD_DIR)
            image_url = f"{origin}/data/image/{relative_path}"
        else:
            image_url = raw_path

    lifestyle = _latest_lifestyle(db, current_user.id)
    height_cm = float(lifestyle.height) if lifestyle and lifestyle.height is not None else None
    weight_kg = float(lifestyle.weight) if lifestyle and lifestyle.weight is not None else None

    return {
        "user_id": current_user.id,
        "email": current_user.email,
        "nickname": current_user.nickname,
        "profile_image_url": image_url,
        "smoking_status": current_user.smoking_status,
        "height_cm": height_cm,
        "weight_kg": weight_kg,
    }


@router.put("/me")
async def update_my_profile(
    request: Request,
    nickname: str = Form(...),
    email: EmailStr = Form(...),
    height_cm: Optional[float] = Form(None),
    weight_kg: Optional[float] = Form(None),
    profile_image: Optional[UploadFile] = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    existing_user = db.query(User).filter(User.email == email, User.id != current_user.id).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 사용 중인 이메일입니다.")

    current_user.nickname = nickname
    current_user.email = email

    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        profile = UserProfile(user_id=current_user.id)
        db.add(profile)

    if profile_image is not None:
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        safe_name = f"profile_{current_user.id}_{timestamp}_{profile_image.filename}"
        save_path = os.path.join(UPLOAD_DIR, safe_name)
        contents = await profile_image.read()
        with open(save_path, "wb") as f:
            f.write(contents)
        profile.profile_image_url = save_path

    lifestyle = _latest_lifestyle(db, current_user.id)
    wants_body = (height_cm is not None and height_cm > 0) or (
        weight_kg is not None and weight_kg > 0
    )
    if lifestyle is None and wants_body:
        lifestyle = Lifestyle(user_id=current_user.id)
        if height_cm is not None and height_cm > 0:
            lifestyle.height = height_cm
        if weight_kg is not None and weight_kg > 0:
            lifestyle.weight = weight_kg
        db.add(lifestyle)
    elif lifestyle is not None:
        if height_cm is not None and height_cm > 0:
            lifestyle.height = height_cm
        if weight_kg is not None and weight_kg > 0:
            lifestyle.weight = weight_kg

    db.commit()
    db.refresh(current_user)
    db.refresh(profile)
    if lifestyle is not None:
        db.refresh(lifestyle)

    origin = resolve_public_api_origin(request)
    image_url = None
    if profile.profile_image_url:
        if os.path.exists(profile.profile_image_url) and UPLOAD_DIR in profile.profile_image_url:
            relative_path = os.path.relpath(profile.profile_image_url, UPLOAD_DIR)
            image_url = f"{origin}/data/image/{relative_path}"
        else:
            image_url = profile.profile_image_url

    out_height = float(lifestyle.height) if lifestyle and lifestyle.height is not None else None
    out_weight = float(lifestyle.weight) if lifestyle and lifestyle.weight is not None else None

    return {
        "message": "프로필이 업데이트되었습니다.",
        "user_id": current_user.id,
        "email": current_user.email,
        "nickname": current_user.nickname,
        "profile_image_url": image_url,
        "height_cm": out_height,
        "weight_kg": out_weight,
    }


# 프로필 보완 API (카카오 가입 후 성별/생년월일 추가 입력)
@router.patch("/me")
def update_profile(
    profile_in: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        birthdate_obj = date.fromisoformat(profile_in.birthdate)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail="생년월일 형식이 올바르지 않습니다. (YYYY-MM-DD)")
    if not profile_in.gender or profile_in.gender.strip() == "":
        raise HTTPException(status_code=400, detail="성별을 선택해주세요.")
    current_user.birthdate = birthdate_obj
    current_user.gender = profile_in.gender
    if profile_in.smoking_status and profile_in.smoking_status.strip() in ("never", "former", "current"):
        current_user.smoking_status = profile_in.smoking_status.strip()
    db.commit()
    db.refresh(current_user)
    return {"message": "프로필이 업데이트되었습니다.", "nickname": current_user.nickname}
