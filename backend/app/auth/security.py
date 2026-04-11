import os
from typing import Optional
from passlib.context import CryptContext
from datetime import datetime, timedelta, timezone
from jose import jwt

# 비밀번호 해싱 설정
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
ALGORITHM = "HS256"

def _get_secret_key() -> str:
    secret_key = os.getenv("JWT_SECRET_KEY") or os.getenv("SECRET_KEY")
    if not secret_key:
        raise RuntimeError("JWT_SECRET_KEY(또는 SECRET_KEY) 환경변수가 필요합니다.")
    return secret_key


def hash_password(password: str):
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict):
    to_encode = data.copy()
    # 액세스는 짧게, 만료 시 클라이언트가 리프레시로 재발급
    expire = datetime.now(timezone.utc) + timedelta(hours=24)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, _get_secret_key(), algorithm=ALGORITHM)

def create_refresh_token(data: dict):
    to_encode = data.copy()
    # 앱 삭제·로그아웃 전 재로그인 최소화
    expire = datetime.now(timezone.utc) + timedelta(days=365)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, _get_secret_key(), algorithm=ALGORITHM)

def verify_token(token: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, _get_secret_key(), algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            print("[토큰 검증] payload에 'sub' 키가 없습니다.")
            return None
        print(f"[토큰 검증] 성공: {email}")
        return email
    except jwt.ExpiredSignatureError:
        print("[토큰 검증] 토큰이 만료되었습니다.")
        return None
    except jwt.JWTError as e:
        print(f"[토큰 검증] JWT 오류: {str(e)}")
        return None
    except Exception as e:
        print(f"[토큰 검증] 예상치 못한 오류: {str(e)}")
        return None

def verify_refresh_token(token: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, _get_secret_key(), algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            return None
        email: str = payload.get("sub")
        return email if email else None
    except jwt.ExpiredSignatureError:
        return None
    except jwt.JWTError:
        return None
    except Exception:
        return None
