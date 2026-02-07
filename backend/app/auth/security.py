from passlib.context import CryptContext
from datetime import datetime, timedelta
from jose import jwt

# 비밀번호 해싱 설정
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
SECRET_KEY = "your-very-secret-key" # 실제로는 환경변수로 관리해야 함
ALGORITHM = "HS256"

def hash_password(password: str):
    # Bcrypt의 30자 제한을 고려하여, 너무 긴 입력은 미리 잘라주거나 예외 처리.
    if len(password.encode('utf-8')) > 30:
        password = password[:30]
    return pwd_context.hash(password)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=60) # 1시간 유효
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
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