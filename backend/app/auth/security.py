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