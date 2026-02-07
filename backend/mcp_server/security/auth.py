"""
인증 및 권한 부여 모듈 (JWT 기반, RBAC, ABAC)
자체 ID/비밀번호 로그인과 통합 가능한 보안 시스템입니다.
"""
from typing import Optional, Dict, List, Any, Set
from datetime import datetime, timedelta
from enum import Enum
import jwt
from passlib.context import CryptContext
from pydantic import BaseModel, Field, EmailStr
import logging

logger = logging.getLogger(__name__)

# 비밀번호 해싱 설정
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ==================== 인증 관련 모델 ====================

class TokenType(str, Enum):
    """토큰 타입"""
    ACCESS = "access"
    REFRESH = "refresh"


class Permission(str, Enum):
    """권한 정의 (Scope)"""
    HEALTH_READ = "health:read"
    HEALTH_WRITE = "health:write"
    LIFESTYLE_READ = "lifestyle:read"
    LIFESTYLE_ANALYZE = "lifestyle:analyze"
    PROFILE_READ = "profile:read"
    PROFILE_WRITE = "profile:write"
    DATA_DELETE = "data:delete"
    ADMIN = "admin:*"


class UserRole(str, Enum):
    """사용자 역할"""
    FREE = "free"
    PREMIUM = "premium"
    ADMIN = "admin"


class TokenPayload(BaseModel):
    """JWT 토큰 페이로드"""
    sub: str  # Subject (user_id)
    email: Optional[str] = None  # 사용자 이메일
    permissions: List[str]  # 허용된 권한 목록
    role: UserRole  # 사용자 역할
    exp: datetime  # Expiration time
    iat: datetime  # Issued at time
    jti: str  # JWT ID (토큰 고유 식별자)
    
    # ABAC 속성
    attributes: Dict[str, Any] = Field(default_factory=dict)


class AccessContext(BaseModel):
    """접근 컨텍스트 (ABAC용)"""
    user_id: str
    email: Optional[str] = None
    role: UserRole
    permissions: Set[str]
    attributes: Dict[str, Any]  # 예: {"is_owner": True, "time": "daytime"}
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None


# ==================== Password Utilities ====================

class PasswordManager:
    """비밀번호 관리 유틸리티"""
    
    @staticmethod
    def hash_password(password: str) -> str:
        """비밀번호 해싱"""
        return pwd_context.hash(password)
    
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """비밀번호 검증"""
        return pwd_context.verify(plain_password, hashed_password)


# ==================== Token Validator ====================

class TokenValidator:
    """JWT 토큰 검증기 (자체 로그인 시스템 호환)"""
    
    def __init__(self, secret_key: str, algorithm: str = "HS256"):
        self.secret_key = secret_key
        self.algorithm = algorithm
        self.revoked_tokens: Set[str] = set()  # 실제 환경에서는 Redis 등 사용
    
    def validate_token(self, token: str) -> TokenPayload:
        """
        액세스 토큰 검증
        
        Raises:
            jwt.ExpiredSignatureError: 토큰 만료
            jwt.InvalidTokenError: 유효하지 않은 토큰
            ValueError: 토큰이 폐기됨
        """
        try:
            # JWT 디코딩
            payload = jwt.decode(
                token,
                self.secret_key,
                algorithms=[self.algorithm]
            )
            
            # 토큰 페이로드 파싱
            token_payload = TokenPayload(**payload)
            
            # 폐기된 토큰인지 확인
            if token_payload.jti in self.revoked_tokens:
                raise ValueError("Token has been revoked")
            
            # 만료 시간 확인
            if token_payload.exp < datetime.utcnow():
                raise jwt.ExpiredSignatureError("Token has expired")
            
            logger.info(f"Token validated for user: {token_payload.sub}")
            return token_payload
            
        except jwt.ExpiredSignatureError:
            logger.warning("Token validation failed: expired")
            raise
        except jwt.InvalidTokenError as e:
            logger.error(f"Token validation failed: {str(e)}")
            raise
    
    def revoke_token(self, jti: str):
        """토큰 폐기"""
        self.revoked_tokens.add(jti)
        logger.info(f"Token revoked: {jti}")
    
    def create_access_token(
        self,
        user_id: str,
        email: str,
        role: UserRole,
        permissions: List[Permission] = None,
        attributes: Dict[str, Any] = None,
        expires_delta: timedelta = timedelta(hours=24)
    ) -> str:
        """
        JWT 액세스 토큰 생성 (로그인 성공 시 호출)
        
        Args:
            user_id: 사용자 ID
            email: 사용자 이메일
            role: 사용자 역할
            permissions: 허용할 권한 목록 (None이면 역할 기본 권한 사용)
            attributes: ABAC 속성
            expires_delta: 토큰 유효 기간 (기본 24시간)
        """
        import uuid
        
        # 권한이 명시되지 않으면 역할의 기본 권한 사용
        if permissions is None:
            permissions = list(RBACPolicy.ROLE_PERMISSIONS.get(role, set()))
        else:
            permissions = [p.value if isinstance(p, Permission) else p for p in permissions]
        
        now = datetime.utcnow()
        payload = TokenPayload(
            sub=user_id,
            email=email,
            permissions=permissions,
            role=role,
            exp=now + expires_delta,
            iat=now,
            jti=str(uuid.uuid4()),
            attributes=attributes or {}
        )
        
        token = jwt.encode(
            payload.model_dump(),
            self.secret_key,
            algorithm=self.algorithm
        )
        
        logger.info(f"Access token created for user: {user_id}")
        return token


# ==================== RBAC (Role-Based Access Control) ====================

class RBACPolicy:
    """역할 기반 접근 제어"""
    
    # 역할별 기본 권한 매핑
    ROLE_PERMISSIONS: Dict[UserRole, Set[Permission]] = {
        UserRole.FREE: {
            Permission.HEALTH_READ,
            Permission.LIFESTYLE_READ,
            Permission.PROFILE_READ,
        },
        UserRole.PREMIUM: {
            Permission.HEALTH_READ,
            Permission.HEALTH_WRITE,
            Permission.LIFESTYLE_READ,
            Permission.LIFESTYLE_ANALYZE,
            Permission.PROFILE_READ,
            Permission.PROFILE_WRITE,
        },
        UserRole.ADMIN: {perm for perm in Permission},  # 모든 권한
    }
    
    @classmethod
    def check_permission(cls, role: UserRole, required_permission: Permission) -> bool:
        """역할이 특정 권한에 접근 가능한지 확인"""
        allowed_permissions = cls.ROLE_PERMISSIONS.get(role, set())
        has_permission = required_permission in allowed_permissions or Permission.ADMIN in allowed_permissions
        
        if not has_permission:
            logger.warning(f"RBAC denied: role={role}, permission={required_permission}")
        
        return has_permission


# ==================== ABAC (Attribute-Based Access Control) ====================

class ABACRule(BaseModel):
    """ABAC 규칙"""
    name: str
    description: str
    condition: str  # Python 표현식 (예: "context.attributes.get('is_owner') == True")
    action: str  # "allow" or "deny"


class ABACPolicy:
    """속성 기반 접근 제어"""
    
    def __init__(self):
        self.rules: List[ABACRule] = self._load_default_rules()
    
    def _load_default_rules(self) -> List[ABACRule]:
        """기본 ABAC 규칙 로드"""
        return [
            ABACRule(
                name="owner_only_data_access",
                description="본인의 데이터만 조회 가능",
                condition="context.attributes.get('requested_user_id') == context.user_id",
                action="allow"
            ),
            ABACRule(
                name="nighttime_access_restriction",
                description="야간 시간대 접근 제한 (23:00-06:00)",
                condition="not (23 <= context.attributes.get('hour', 12) or context.attributes.get('hour', 12) < 6)",
                action="allow"
            ),
            ABACRule(
                name="rate_limit_check",
                description="속도 제한 확인",
                condition="context.attributes.get('request_count_today', 0) < context.attributes.get('daily_limit', 1000)",
                action="allow"
            ),
            ABACRule(
                name="sensitive_data_premium_only",
                description="민감 데이터는 프리미엄 사용자만",
                condition="not context.attributes.get('is_sensitive') or context.role == 'premium' or context.role == 'admin'",
                action="allow"
            ),
        ]
    
    def evaluate(self, context: AccessContext) -> bool:
        """
        ABAC 규칙 평가
        
        Returns:
            True if access is allowed, False otherwise
        """
        try:
            for rule in self.rules:
                # 안전한 평가 환경 구성
                eval_context = {
                    "context": context,
                    "datetime": datetime,
                }
                
                # 조건 평가
                result = eval(rule.condition, {"__builtins__": {}}, eval_context)
                
                if rule.action == "deny" and result:
                    logger.warning(f"ABAC denied by rule: {rule.name}")
                    return False
                
                if rule.action == "allow" and not result:
                    logger.warning(f"ABAC denied by rule: {rule.name}")
                    return False
            
            logger.info("ABAC evaluation passed")
            return True
            
        except Exception as e:
            logger.error(f"ABAC evaluation error: {str(e)}")
            return False


# ==================== Security Manager ====================

class SecurityManager:
    """통합 보안 관리자"""
    
    def __init__(self, secret_key: str):
        self.token_validator = TokenValidator(secret_key)
        self.rbac = RBACPolicy()
        self.abac = ABACPolicy()
    
    async def authenticate_and_authorize(
        self,
        token: str,
        required_permission: Permission,
        context_attributes: Dict[str, Any] = None
    ) -> AccessContext:
        """
        인증 및 권한 부여 통합 프로세스
        
        Args:
            token: JWT 액세스 토큰
            required_permission: 필요한 권한
            context_attributes: ABAC 평가를 위한 추가 속성
        
        Returns:
            AccessContext: 접근 컨텍스트
        
        Raises:
            PermissionError: 권한 부족
            ValueError: 유효하지 않은 토큰
        """
        # 1. 토큰 검증 (OAuth)
        try:
            token_payload = self.token_validator.validate_token(token)
        except Exception as e:
            raise ValueError(f"Token validation failed: {str(e)}")
        
        # 2. RBAC 확인
        if not self.rbac.check_permission(token_payload.role, required_permission):
            raise PermissionError(
                f"Role '{token_payload.role}' does not have permission '{required_permission}'"
            )
        
        # 3. 권한 확인
        if required_permission.value not in token_payload.permissions:
            raise PermissionError(
                f"Token does not have required permission: {required_permission}"
            )
        
        # 4. AccessContext 생성
        merged_attributes = {**token_payload.attributes, **(context_attributes or {})}
        access_context = AccessContext(
            user_id=token_payload.sub,
            email=token_payload.email,
            role=token_payload.role,
            permissions=set(token_payload.permissions),
            attributes=merged_attributes
        )
        
        # 5. ABAC 평가
        if not self.abac.evaluate(access_context):
            raise PermissionError("Access denied by attribute-based policy")
        
        logger.info(f"Authentication and authorization successful for user: {token_payload.sub}")
        return access_context


# ==================== 사용 예시 ====================

if __name__ == "__main__":
    # 예시: 비밀번호 해싱
    password_manager = PasswordManager()
    hashed = password_manager.hash_password("mypassword123")
    print(f"Hashed password: {hashed}")
    print(f"Verification: {password_manager.verify_password('mypassword123', hashed)}")
    
    # 예시: 보안 관리자 초기화
    security_manager = SecurityManager(secret_key="your-secret-key-here")
    
    # 예시: 로그인 후 토큰 생성
    token = security_manager.token_validator.create_access_token(
        user_id="user123",
        email="user@example.com",
        role=UserRole.PREMIUM,
        permissions=[Permission.HEALTH_READ, Permission.LIFESTYLE_ANALYZE],
        attributes={
            "is_owner": True,
            "hour": 14,  # 오후 2시
            "request_count_today": 50,
            "daily_limit": 1000
        }
    )
    
    print(f"Generated Token: {token[:50]}...")
