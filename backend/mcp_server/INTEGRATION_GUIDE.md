# 자체 로그인 시스템 통합 가이드

## 개요

`security/auth.py`는 **자체 ID/비밀번호 로그인 시스템**과 완벽하게 호환됩니다.
OAuth 2.1 용어는 제거하고, 일반적인 JWT 기반 인증으로 수정되었습니다.

## 주요 변경 사항

### Before (OAuth 2.1)
- ~~OAuth Scope~~ → **Permission**
- ~~OAuth Resource Server~~ → **JWT 기반 인증**
- ~~Short-lived Token (15분)~~ → **일반 토큰 (24시간 기본)**

### After (자체 인증)
- ✅ JWT 토큰 생성/검증
- ✅ 비밀번호 해싱/검증 (bcrypt)
- ✅ RBAC (역할 기반 권한)
- ✅ ABAC (속성 기반 권한)
- ✅ 토큰 폐기 (로그아웃)

## 통합 3단계

### 1단계: 회원가입 시 비밀번호 해싱

```python
from security.auth import PasswordManager

password_manager = PasswordManager()

# 회원가입
@router.post("/register")
def register(email: str, password: str, nickname: str):
    # 비밀번호 해싱
    hashed_password = password_manager.hash_password(password)
    
    # DB에 저장
    user = User(
        email=email,
        hashed_password=hashed_password,
        nickname=nickname
    )
    db.add(user)
    db.commit()
    
    return {"message": "registered"}
```

### 2단계: 로그인 시 토큰 생성

```python
from security.auth import SecurityManager, UserRole, PasswordManager

SECRET_KEY = "your-secret-key"
security_manager = SecurityManager(secret_key=SECRET_KEY)
password_manager = PasswordManager()

# 로그인
@router.post("/login")
def login(email: str, password: str):
    # 1. 사용자 조회
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(401, "Invalid credentials")
    
    # 2. 비밀번호 검증
    if not password_manager.verify_password(password, user.hashed_password):
        raise HTTPException(401, "Invalid credentials")
    
    # 3. JWT 토큰 생성
    access_token = security_manager.token_validator.create_access_token(
        user_id=str(user.id),
        email=user.email,
        role=UserRole.PREMIUM,  # 사용자 역할에 따라
        permissions=None,  # None이면 역할의 기본 권한 사용
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }
```

### 3단계: 보호된 라우트에서 토큰 검증

```python
from fastapi import Header, HTTPException

async def get_current_user(authorization: str = Header(...)):
    """모든 보호된 라우트에서 사용"""
    # "Bearer <token>" 형식
    token = authorization.split("Bearer ")[1]
    
    # 토큰 검증
    try:
        token_payload = security_manager.token_validator.validate_token(token)
        return {
            "user_id": token_payload.sub,
            "email": token_payload.email,
            "role": token_payload.role,
            "permissions": token_payload.permissions,
        }
    except Exception:
        raise HTTPException(401, "Invalid token")

# 보호된 라우트 예시
@router.get("/me")
async def get_me(current_user = Depends(get_current_user)):
    return current_user
```

## 역할 및 권한 설정

### 역할 정의

```python
from security.auth import UserRole

# 무료 사용자
UserRole.FREE

# 프리미엄 사용자
UserRole.PREMIUM

# 관리자
UserRole.ADMIN
```

### 역할별 기본 권한

```python
FREE:
  - health:read
  - lifestyle:read
  - profile:read

PREMIUM:
  - health:read, health:write
  - lifestyle:read, lifestyle:analyze
  - profile:read, profile:write

ADMIN:
  - 모든 권한
```

### 커스텀 권한 부여

```python
from security.auth import Permission

# 특정 사용자에게 추가 권한 부여
access_token = security_manager.token_validator.create_access_token(
    user_id=str(user.id),
    email=user.email,
    role=UserRole.FREE,
    permissions=[
        Permission.HEALTH_READ,
        Permission.LIFESTYLE_ANALYZE,  # 무료 사용자지만 분석 권한 추가
    ]
)
```

## 로그아웃 (토큰 폐기)

```python
@router.post("/logout")
def logout(authorization: str = Header(...)):
    token = authorization.split("Bearer ")[1]
    
    # 토큰 검증 및 폐기
    token_payload = security_manager.token_validator.validate_token(token)
    security_manager.token_validator.revoke_token(token_payload.jti)
    
    return {"message": "logged out"}
```

## 프로덕션 체크리스트

- [ ] `JWT_SECRET_KEY`를 환경 변수로 설정
- [ ] 토큰 폐기 목록을 Redis에 저장 (현재는 메모리)
- [ ] 토큰 유효기간 조정 (기본 24시간)
- [ ] HTTPS 적용
- [ ] 비밀번호 정책 적용 (최소 8자, 특수문자 포함 등)

## 전체 예시 코드

[auth_integration_example.py](examples/auth_integration_example.py) 참조

## 자주 묻는 질문

### Q1: 기존 JWT 토큰과 호환되나요?
A: 호환됩니다. 동일한 `SECRET_KEY`를 사용하면 됩니다.

### Q2: 토큰 유효기간을 변경하려면?
A: `create_access_token(expires_delta=timedelta(hours=48))` 파라미터 사용

### Q3: 역할을 추가하려면?
A: `security/auth.py`의 `UserRole` Enum에 추가하고 `ROLE_PERMISSIONS`에 권한 매핑

### Q4: 카카오 로그인도 지원하나요?
A: 지원합니다. 카카오 인증 후 동일하게 JWT 토큰 생성하면 됩니다.

```python
# 카카오 로그인 후
@router.post("/kakao-login")
def kakao_login(kakao_token: str):
    # 1. 카카오 토큰으로 사용자 정보 조회
    kakao_user = get_kakao_user_info(kakao_token)
    
    # 2. DB에서 사용자 조회 또는 생성
    user = get_or_create_user(kakao_id=kakao_user.id)
    
    # 3. JWT 토큰 생성 (동일한 방식)
    access_token = security_manager.token_validator.create_access_token(
        user_id=str(user.id),
        email=kakao_user.email,
        role=UserRole.FREE
    )
    
    return {"access_token": access_token}
```

### Q5: MCP 서버와 FastAPI 서버가 분리되어 있는데?
A: 동일한 `SECRET_KEY`를 공유하면 토큰이 양쪽에서 모두 유효합니다.

```
FastAPI 서버 (로그인/회원가입)
  ↓ JWT 토큰 생성 (SECRET_KEY)
클라이언트
  ↓ JWT 토큰 전달
MCP 서버 (데이터 조회)
  ↓ JWT 토큰 검증 (동일한 SECRET_KEY)
```

## 마이그레이션 가이드

### 기존 시스템에서 통합하기

1. **기존 코드 백업**
```bash
cp backend/api/auth.py backend/api/auth.py.backup
```

2. **PasswordManager 도입**
```python
# 기존
hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt())

# 새로운 방식
from security.auth import PasswordManager
password_manager = PasswordManager()
hashed = password_manager.hash_password(password)
```

3. **JWT 토큰 생성 변경**
```python
# 기존
token = jwt.encode({"user_id": user.id}, SECRET_KEY)

# 새로운 방식
token = security_manager.token_validator.create_access_token(
    user_id=str(user.id),
    email=user.email,
    role=UserRole.PREMIUM
)
```

4. **테스트**
```bash
# 회원가입
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123","nickname":"테스터"}'

# 로그인
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# 보호된 라우트
curl http://localhost:8000/api/auth/me \
  -H "Authorization: Bearer <토큰>"
```

## 지원

문의사항이 있으면 [auth_integration_example.py](examples/auth_integration_example.py)를 참조하거나 팀에 문의하세요.
