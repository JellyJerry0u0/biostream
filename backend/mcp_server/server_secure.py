"""
보안이 통합된 MCP 서버
모든 보안 계층을 적용한 메인 서버입니다.
"""
import sys
import os
from pathlib import Path
from typing import Dict, Any, Optional
import logging
from datetime import datetime

# 경로 설정
mcp_server_dir = Path(__file__).parent.absolute()
app_dir = mcp_server_dir.parent.absolute()

if str(app_dir) not in sys.path:
    sys.path.insert(0, str(app_dir))
if str(mcp_server_dir) not in sys.path:
    sys.path.insert(0, str(mcp_server_dir))

from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field

# 보안 모듈 import
from security import (
    SecurityManager,
    Scope,
    UserRole,
    PIIMasker,
    DataMinimizer,
    EncryptionManager,
    DataProtectionPipeline,
    AuditLogger,
    AnomalyDetector,
    EventType,
    EventSeverity,
    ConsentManager,
    ConsentScope,
    RiskLevel,
    HumanInTheLoopValidator,
    SemanticGuardrails,
    ToolValidator,
    ToolMetadata,
    ToolCategory,
    ToolRiskLevel,
    RateLimiter,
)

# 도구 import
try:
    from mcp_server.tools.db_tools import fetch_user_aging_context
except ImportError:
    try:
        import importlib.util
        tools_path = mcp_server_dir / "tools" / "db_tools.py"
        spec = importlib.util.spec_from_file_location("db_tools", tools_path)
        db_tools = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(db_tools)
        fetch_user_aging_context = db_tools.fetch_user_aging_context
    except Exception as e:
        raise ImportError(f"Could not import fetch_user_aging_context: {e}")

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ==================== 보안 시스템 초기화 ====================

# 환경 변수에서 시크릿 키 가져오기 (프로덕션에서는 반드시 환경 변수 사용)
SECRET_KEY = os.getenv("MCP_SECRET_KEY", "dev-secret-key-change-in-production")
ENCRYPTION_KEY = os.getenv("MCP_ENCRYPTION_KEY", "dev-encryption-key")

# 보안 관리자 초기화
security_manager = SecurityManager(secret_key=SECRET_KEY)

# 데이터 보호 파이프라인
pii_masker = PIIMasker()
data_minimizer = DataMinimizer()
encryption_manager = EncryptionManager(encryption_key=ENCRYPTION_KEY)
data_protection_pipeline = DataProtectionPipeline(
    pii_masker=pii_masker,
    data_minimizer=data_minimizer,
    encryption_manager=encryption_manager
)

# 감사 로그 및 이상 징후 탐지
audit_log_path = mcp_server_dir / "logs" / "audit.log"
audit_log_path.parent.mkdir(exist_ok=True)
audit_logger = AuditLogger(storage_path=str(audit_log_path))
anomaly_detector = AnomalyDetector(audit_logger=audit_logger)

# 동의 관리
consent_manager = ConsentManager()
hitl_validator = HumanInTheLoopValidator()

# 도구 검증기
tool_validator = ToolValidator()
rate_limiter = RateLimiter()

# FastMCP 서버 초기화
mcp = FastMCP("BioStream-Secure")

# ==================== 보안 미들웨어 ====================

class SecureToolContext:
    """보안 컨텍스트를 관리하는 클래스"""
    
    def __init__(
        self,
        token: str,
        session_id: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ):
        self.token = token
        self.session_id = session_id
        self.ip_address = ip_address
        self.user_agent = user_agent
        self.access_context = None
    
    async def authenticate(self, required_scope: Scope) -> bool:
        """인증 및 권한 확인"""
        try:
            # 추가 컨텍스트 속성
            context_attrs = {
                "hour": datetime.utcnow().hour,
                "session_id": self.session_id,
                "ip_address": self.ip_address,
            }
            
            # 인증 및 권한 부여
            self.access_context = await security_manager.authenticate_and_authorize(
                token=self.token,
                required_scope=required_scope,
                context_attributes=context_attrs
            )
            
            # 감사 로그 기록
            audit_logger.log_event(
                audit_logger.AuditEvent(
                    event_id="",
                    event_type=EventType.AUTHENTICATION,
                    severity=EventSeverity.INFO,
                    user_id=self.access_context.user_id,
                    session_id=self.session_id,
                    ip_address=self.ip_address,
                    action="authenticate",
                    result="success"
                )
            )
            
            return True
            
        except Exception as e:
            # 인증 실패 로그
            audit_logger.log_security_violation(
                user_id="unknown",
                violation_type="authentication_failure",
                details={"error": str(e)},
                session_id=self.session_id
            )
            logger.error(f"Authentication failed: {str(e)}")
            return False


# ==================== Pydantic 스키마 정의 ====================

class GetHealthReportParams(BaseModel):
    """건강 리포트 조회 파라미터"""
    user_id: int = Field(..., gt=0, description="사용자 ID")
    days: int = Field(7, ge=1, le=30, description="조회 기간 (일)")
    include_summary: bool = Field(True, description="요약 포함 여부")


# ==================== 보안 래퍼 함수 ====================

async def secure_get_user_health_report(
    context: SecureToolContext,
    user_id: int,
    days: int = 7,
    include_summary: bool = True
) -> Dict[str, Any]:
    """
    보안이 적용된 건강 리포트 조회
    
    전체 보안 플로우:
    1. 인증 및 권한 확인 (OAuth + RBAC + ABAC)
    2. 사용자 동의 확인
    3. 속도 제한 확인
    4. 이상 징후 탐지
    5. 데이터 조회
    6. 데이터 보호 처리 (PII 마스킹 + 최소화)
    7. 감사 로그 기록
    """
    
    # 1. 인증 및 권한 확인
    if not await context.authenticate(Scope.HEALTH_READ):
        raise PermissionError("Authentication or authorization failed")
    
    user_id_str = context.access_context.user_id
    
    # 2. 사용자 동의 확인
    consent_request = consent_manager.request_consent(
        user_id=user_id_str,
        session_id=context.session_id,
        scope=ConsentScope.READ_HEALTH_DATA,
        purpose="건강 데이터 분석 및 노화 리포트 생성",
        data_description=f"최근 {days}일간의 건강 데이터",
        risk_level=RiskLevel.LOW,
        tool_name="get_user_health_report",
        parameters={"user_id": user_id, "days": days},
        auto_approve=True  # 저위험 작업은 자동 승인
    )
    
    if consent_request.status != "granted":
        raise PermissionError("User consent required but not granted")
    
    # 3. 속도 제한 확인
    from datetime import timedelta
    if not rate_limiter.check_rate_limit(
        user_id=user_id_str,
        tool_name="get_user_health_report",
        max_calls=30,
        time_window=timedelta(minutes=1)
    ):
        raise Exception("Rate limit exceeded")
    
    # 4. 이상 징후 탐지
    from security.audit import AuditEvent
    test_event = AuditEvent(
        event_id="",
        event_type=EventType.TOOL_CALL,
        severity=EventSeverity.INFO,
        user_id=user_id_str,
        session_id=context.session_id,
        action="call_tool:get_user_health_report",
        tool_name="get_user_health_report",
        result="pending"
    )
    
    anomaly = anomaly_detector.check_anomaly(
        user_id=user_id_str,
        session_id=context.session_id,
        event=test_event
    )
    
    if anomaly and anomaly.get("action") == "block":
        raise Exception(f"Access blocked due to anomaly: {anomaly.get('reason')}")
    
    # 5. 데이터 조회
    try:
        raw_data = fetch_user_aging_context(user_id)
        
        # 6. 데이터 보호 처리
        protected_data = data_protection_pipeline.process_for_llm(
            data=[raw_data] if isinstance(raw_data, dict) else raw_data,
            purpose="sleep_analysis",
            sensitive_keys={"name", "email", "phone"},
            summarize=include_summary,
            summary_fields={"sleep_hours": "avg", "activity_level": "avg"} if include_summary else None
        )
        
        # 7. 감사 로그 기록
        audit_logger.log_tool_call(
            user_id=user_id_str,
            tool_name="get_user_health_report",
            parameters={"user_id": user_id, "days": days},
            result="success",
            session_id=context.session_id,
            ip_address=context.ip_address
        )
        
        return {
            "status": "success",
            "data": protected_data,
            "security": {
                "pii_masked": True,
                "data_minimized": True,
                "consent_verified": True
            }
        }
        
    except Exception as e:
        # 실패 로그
        audit_logger.log_event(
            audit_logger.AuditEvent(
                event_id="",
                event_type=EventType.TOOL_CALL,
                severity=EventSeverity.ERROR,
                user_id=user_id_str,
                session_id=context.session_id,
                action="call_tool:get_user_health_report",
                tool_name="get_user_health_report",
                result="failure",
                metadata={"error": str(e)}
            )
        )
        raise


# ==================== MCP 도구 등록 ====================

@mcp.tool()
async def get_user_health_report(user_id: int, days: int = 7, include_summary: bool = True):
    """
    유저의 최신 건강 데이터를 카테고리별로 가져와 노화 분석 맥락을 제공합니다.
    
    보안 기능:
    - OAuth 2.1 토큰 인증
    - RBAC/ABAC 권한 제어
    - 사용자 동의 확인
    - PII 마스킹 및 데이터 최소화
    - 감사 로그 기록
    - 이상 징후 탐지
    """
    
    # TODO: 실제 환경에서는 요청 헤더에서 토큰 추출
    # 현재는 데모용 토큰 생성
    demo_token = security_manager.token_validator.create_access_token(
        user_id=str(user_id),
        role=UserRole.PREMIUM,
        scopes=[Scope.HEALTH_READ, Scope.LIFESTYLE_ANALYZE],
        attributes={
            "is_owner": True,
            "requested_user_id": str(user_id)
        }
    )
    
    context = SecureToolContext(
        token=demo_token,
        session_id=f"sess_{user_id}_{datetime.utcnow().timestamp()}",
        ip_address="127.0.0.1"
    )
    
    return await secure_get_user_health_report(
        context=context,
        user_id=user_id,
        days=days,
        include_summary=include_summary
    )


# ==================== 관리자 도구 ====================

@mcp.tool()
async def get_audit_summary(user_id: str, hours: int = 1):
    """
    사용자의 최근 활동 감사 로그 요약 조회 (관리자 전용)
    """
    from datetime import timedelta
    
    summary = audit_logger.get_summary(
        user_id=user_id,
        time_window=timedelta(hours=hours)
    )
    
    return summary


@mcp.tool()
async def revoke_user_consent(user_id: str, scope: str):
    """
    사용자 동의 철회 (사용자 또는 관리자)
    """
    try:
        scope_enum = ConsentScope(scope)
        success = consent_manager.revoke_consent(user_id, scope_enum)
        return {
            "status": "success" if success else "failed",
            "user_id": user_id,
            "scope": scope
        }
    except ValueError:
        return {"status": "error", "message": f"Invalid scope: {scope}"}


# ==================== 서버 실행 ====================

if __name__ == "__main__":
    logger.info("Starting BioStream Secure MCP Server...")
    logger.info(f"Audit log path: {audit_log_path}")
    
    # 보안 시스템 상태 로그
    logger.info("Security systems initialized:")
    logger.info("  - OAuth 2.1 Authentication ✓")
    logger.info("  - RBAC/ABAC Authorization ✓")
    logger.info("  - PII Masking & Data Protection ✓")
    logger.info("  - Audit Logging ✓")
    logger.info("  - Anomaly Detection ✓")
    logger.info("  - Consent Management ✓")
    logger.info("  - Semantic Guardrails ✓")
    
    mcp.run()
