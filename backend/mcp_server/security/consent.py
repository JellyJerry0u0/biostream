"""
사용자 동의 및 제어 메커니즘 (User Consent & Human-in-the-Loop)
AI의 데이터 접근 및 작업 수행에 대한 사용자 동의를 관리합니다.
"""
from typing import Dict, Any, List, Optional, Set
from datetime import datetime, timedelta
from enum import Enum
from pydantic import BaseModel, Field
import logging

logger = logging.getLogger(__name__)


# ==================== 동의 관련 모델 ====================

class ConsentScope(str, Enum):
    """동의 범위"""
    READ_HEALTH_DATA = "read_health_data"
    READ_LIFESTYLE_DATA = "read_lifestyle_data"
    ANALYZE_DATA = "analyze_data"
    GENERATE_RECOMMENDATIONS = "generate_recommendations"
    MODIFY_SETTINGS = "modify_settings"
    DELETE_DATA = "delete_data"


class ConsentStatus(str, Enum):
    """동의 상태"""
    PENDING = "pending"
    GRANTED = "granted"
    DENIED = "denied"
    EXPIRED = "expired"
    REVOKED = "revoked"


class RiskLevel(str, Enum):
    """작업 위험도"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ConsentRequest(BaseModel):
    """동의 요청"""
    request_id: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    user_id: str
    session_id: str
    
    # 동의 내용
    scope: ConsentScope
    purpose: str  # 사용 목적 설명
    data_description: str  # 접근할 데이터 설명
    risk_level: RiskLevel
    
    # 요청 상세
    tool_name: str
    parameters: Dict[str, Any]
    
    # 상태
    status: ConsentStatus = ConsentStatus.PENDING
    expires_at: Optional[datetime] = None
    
    # 사용자 응답
    user_response: Optional[str] = None
    responded_at: Optional[datetime] = None


class ConsentRecord(BaseModel):
    """동의 기록"""
    user_id: str
    scope: ConsentScope
    granted_at: datetime
    expires_at: Optional[datetime] = None
    revoked_at: Optional[datetime] = None
    is_active: bool = True


# ==================== Consent Manager ====================

class ConsentManager:
    """
    사용자 동의 관리자
    AI가 민감 데이터에 접근하기 전 사용자 승인을 요청합니다.
    """
    
    def __init__(self):
        # 동의 요청 저장소
        self.consent_requests: Dict[str, ConsentRequest] = {}
        
        # 사용자별 동의 기록
        self.consent_records: Dict[str, List[ConsentRecord]] = {}
        
        # 범위별 기본 유효 기간
        self.default_expiry: Dict[ConsentScope, timedelta] = {
            ConsentScope.READ_HEALTH_DATA: timedelta(hours=1),
            ConsentScope.READ_LIFESTYLE_DATA: timedelta(hours=1),
            ConsentScope.ANALYZE_DATA: timedelta(minutes=30),
            ConsentScope.GENERATE_RECOMMENDATIONS: timedelta(minutes=30),
            ConsentScope.MODIFY_SETTINGS: timedelta(minutes=5),
            ConsentScope.DELETE_DATA: timedelta(minutes=5),
        }
        
        # 자동 승인 가능 범위 (저위험)
        self.auto_approve_scopes: Set[ConsentScope] = {
            ConsentScope.READ_HEALTH_DATA,
            ConsentScope.READ_LIFESTYLE_DATA,
        }
    
    def request_consent(
        self,
        user_id: str,
        session_id: str,
        scope: ConsentScope,
        purpose: str,
        data_description: str,
        risk_level: RiskLevel,
        tool_name: str,
        parameters: Dict[str, Any],
        auto_approve: bool = False
    ) -> ConsentRequest:
        """
        동의 요청 생성
        
        Args:
            user_id: 사용자 ID
            session_id: 세션 ID
            scope: 동의 범위
            purpose: 사용 목적
            data_description: 데이터 설명
            risk_level: 위험 수준
            tool_name: 도구 이름
            parameters: 파라미터
            auto_approve: 자동 승인 여부
        
        Returns:
            ConsentRequest: 동의 요청 객체
        """
        import uuid
        
        # 기존 유효한 동의가 있는지 확인
        if self.has_valid_consent(user_id, scope):
            logger.info(f"Existing valid consent found for {user_id}, scope={scope}")
            # 자동 승인 처리
            request_id = str(uuid.uuid4())
            request = ConsentRequest(
                request_id=request_id,
                user_id=user_id,
                session_id=session_id,
                scope=scope,
                purpose=purpose,
                data_description=data_description,
                risk_level=risk_level,
                tool_name=tool_name,
                parameters=parameters,
                status=ConsentStatus.GRANTED,
                expires_at=datetime.utcnow() + self.default_expiry.get(scope, timedelta(minutes=30))
            )
            self.consent_requests[request_id] = request
            return request
        
        # 새 동의 요청 생성
        request_id = str(uuid.uuid4())
        request = ConsentRequest(
            request_id=request_id,
            user_id=user_id,
            session_id=session_id,
            scope=scope,
            purpose=purpose,
            data_description=data_description,
            risk_level=risk_level,
            tool_name=tool_name,
            parameters=parameters,
            expires_at=datetime.utcnow() + timedelta(minutes=5)  # 요청 자체의 유효 기간
        )
        
        self.consent_requests[request_id] = request
        
        # 자동 승인 조건 확인
        if auto_approve and scope in self.auto_approve_scopes and risk_level == RiskLevel.LOW:
            self.grant_consent(request_id, auto=True)
            logger.info(f"Consent auto-approved: {request_id}")
        else:
            logger.info(f"Consent requested: {request_id}, waiting for user response")
        
        return request
    
    def grant_consent(self, request_id: str, auto: bool = False) -> bool:
        """
        동의 승인
        
        Args:
            request_id: 요청 ID
            auto: 자동 승인 여부
        
        Returns:
            성공 여부
        """
        request = self.consent_requests.get(request_id)
        if not request:
            logger.error(f"Consent request not found: {request_id}")
            return False
        
        if request.status != ConsentStatus.PENDING:
            logger.warning(f"Consent request already processed: {request_id}")
            return False
        
        # 요청이 만료되었는지 확인
        if request.expires_at and request.expires_at < datetime.utcnow():
            request.status = ConsentStatus.EXPIRED
            logger.warning(f"Consent request expired: {request_id}")
            return False
        
        # 동의 승인
        request.status = ConsentStatus.GRANTED
        request.responded_at = datetime.utcnow()
        request.user_response = "auto_approved" if auto else "granted"
        
        # 동의 기록 저장
        expiry = datetime.utcnow() + self.default_expiry.get(request.scope, timedelta(minutes=30))
        record = ConsentRecord(
            user_id=request.user_id,
            scope=request.scope,
            granted_at=datetime.utcnow(),
            expires_at=expiry,
            is_active=True
        )
        
        if request.user_id not in self.consent_records:
            self.consent_records[request.user_id] = []
        self.consent_records[request.user_id].append(record)
        
        logger.info(f"Consent granted: {request_id}, expires at {expiry}")
        return True
    
    def deny_consent(self, request_id: str, reason: Optional[str] = None) -> bool:
        """
        동의 거부
        
        Args:
            request_id: 요청 ID
            reason: 거부 사유
        
        Returns:
            성공 여부
        """
        request = self.consent_requests.get(request_id)
        if not request:
            logger.error(f"Consent request not found: {request_id}")
            return False
        
        if request.status != ConsentStatus.PENDING:
            logger.warning(f"Consent request already processed: {request_id}")
            return False
        
        # 동의 거부
        request.status = ConsentStatus.DENIED
        request.responded_at = datetime.utcnow()
        request.user_response = reason or "denied"
        
        logger.info(f"Consent denied: {request_id}, reason: {reason}")
        return True
    
    def has_valid_consent(self, user_id: str, scope: ConsentScope) -> bool:
        """
        유효한 동의가 있는지 확인
        
        Args:
            user_id: 사용자 ID
            scope: 동의 범위
        
        Returns:
            유효한 동의 존재 여부
        """
        records = self.consent_records.get(user_id, [])
        
        for record in records:
            if (
                record.scope == scope
                and record.is_active
                and not record.revoked_at
                and (not record.expires_at or record.expires_at > datetime.utcnow())
            ):
                return True
        
        return False
    
    def revoke_consent(self, user_id: str, scope: ConsentScope) -> bool:
        """
        동의 철회
        
        Args:
            user_id: 사용자 ID
            scope: 동의 범위
        
        Returns:
            성공 여부
        """
        records = self.consent_records.get(user_id, [])
        revoked_count = 0
        
        for record in records:
            if record.scope == scope and record.is_active:
                record.is_active = False
                record.revoked_at = datetime.utcnow()
                revoked_count += 1
        
        logger.info(f"Consent revoked: user={user_id}, scope={scope}, count={revoked_count}")
        return revoked_count > 0
    
    def get_user_consents(self, user_id: str) -> List[ConsentRecord]:
        """사용자의 모든 동의 기록 조회"""
        return self.consent_records.get(user_id, [])
    
    def get_pending_requests(self, user_id: str) -> List[ConsentRequest]:
        """사용자의 대기 중인 동의 요청 조회"""
        return [
            req for req in self.consent_requests.values()
            if req.user_id == user_id and req.status == ConsentStatus.PENDING
        ]


# ==================== Human-in-the-Loop Validator ====================

class HITLAction(BaseModel):
    """Human-in-the-Loop 검증이 필요한 작업"""
    action_id: str
    user_id: str
    session_id: str
    
    # 작업 정보
    action_type: str  # "data_deletion", "health_advice_execution", etc.
    description: str
    risk_level: RiskLevel
    
    # 작업 상세
    tool_name: str
    parameters: Dict[str, Any]
    impact_summary: str  # 작업의 영향 요약
    
    # 상태
    status: ConsentStatus = ConsentStatus.PENDING
    created_at: datetime = Field(default_factory=datetime.utcnow)
    expires_at: datetime
    
    # 사용자 응답
    user_confirmation: Optional[bool] = None
    confirmed_at: Optional[datetime] = None


class HumanInTheLoopValidator:
    """
    Human-in-the-Loop 검증기
    고위험 작업은 AI가 독단적으로 수행하지 못하게 하고, 사용자의 최종 확인을 요구합니다.
    """
    
    # 고위험 작업 정의
    HIGH_RISK_ACTIONS = {
        "delete_user_data",
        "execute_health_advice",
        "modify_user_settings",
        "export_sensitive_data",
        "share_data_externally",
    }
    
    def __init__(self):
        self.pending_actions: Dict[str, HITLAction] = {}
    
    def requires_human_approval(self, tool_name: str, risk_level: RiskLevel) -> bool:
        """
        Human-in-the-Loop 검증이 필요한지 확인
        
        Args:
            tool_name: 도구 이름
            risk_level: 위험 수준
        
        Returns:
            검증 필요 여부
        """
        # 고위험 작업이거나 위험 수준이 HIGH 이상인 경우
        return tool_name in self.HIGH_RISK_ACTIONS or risk_level in {RiskLevel.HIGH, RiskLevel.CRITICAL}
    
    def request_approval(
        self,
        user_id: str,
        session_id: str,
        action_type: str,
        description: str,
        risk_level: RiskLevel,
        tool_name: str,
        parameters: Dict[str, Any],
        impact_summary: str
    ) -> HITLAction:
        """
        사용자 승인 요청
        
        Returns:
            HITLAction: 승인 요청 객체
        """
        import uuid
        
        action_id = str(uuid.uuid4())
        action = HITLAction(
            action_id=action_id,
            user_id=user_id,
            session_id=session_id,
            action_type=action_type,
            description=description,
            risk_level=risk_level,
            tool_name=tool_name,
            parameters=parameters,
            impact_summary=impact_summary,
            expires_at=datetime.utcnow() + timedelta(minutes=10)  # 10분 내 응답 필요
        )
        
        self.pending_actions[action_id] = action
        
        logger.info(f"Human approval requested: {action_id}, action={action_type}")
        return action
    
    def confirm_action(self, action_id: str) -> bool:
        """
        작업 확인
        
        Args:
            action_id: 작업 ID
        
        Returns:
            성공 여부
        """
        action = self.pending_actions.get(action_id)
        if not action:
            logger.error(f"Action not found: {action_id}")
            return False
        
        if action.status != ConsentStatus.PENDING:
            logger.warning(f"Action already processed: {action_id}")
            return False
        
        # 만료 확인
        if action.expires_at < datetime.utcnow():
            action.status = ConsentStatus.EXPIRED
            logger.warning(f"Action expired: {action_id}")
            return False
        
        # 확인 처리
        action.status = ConsentStatus.GRANTED
        action.user_confirmation = True
        action.confirmed_at = datetime.utcnow()
        
        logger.info(f"Action confirmed: {action_id}")
        return True
    
    def reject_action(self, action_id: str) -> bool:
        """
        작업 거부
        
        Args:
            action_id: 작업 ID
        
        Returns:
            성공 여부
        """
        action = self.pending_actions.get(action_id)
        if not action:
            logger.error(f"Action not found: {action_id}")
            return False
        
        if action.status != ConsentStatus.PENDING:
            logger.warning(f"Action already processed: {action_id}")
            return False
        
        # 거부 처리
        action.status = ConsentStatus.DENIED
        action.user_confirmation = False
        action.confirmed_at = datetime.utcnow()
        
        logger.info(f"Action rejected: {action_id}")
        return True
    
    def get_pending_actions(self, user_id: str) -> List[HITLAction]:
        """사용자의 대기 중인 작업 조회"""
        return [
            action for action in self.pending_actions.values()
            if action.user_id == user_id and action.status == ConsentStatus.PENDING
        ]


# ==================== 사용 예시 ====================

if __name__ == "__main__":
    # Consent Manager 초기화
    consent_manager = ConsentManager()
    
    # 동의 요청
    consent_request = consent_manager.request_consent(
        user_id="user123",
        session_id="sess_abc",
        scope=ConsentScope.READ_HEALTH_DATA,
        purpose="수면 패턴 분석",
        data_description="최근 7일간의 수면 기록",
        risk_level=RiskLevel.LOW,
        tool_name="get_sleep_data",
        parameters={"days": 7},
        auto_approve=True
    )
    
    print(f"Consent Request Status: {consent_request.status}")
    
    # HITL Validator 초기화
    hitl = HumanInTheLoopValidator()
    
    # 고위험 작업 승인 요청
    action = hitl.request_approval(
        user_id="user123",
        session_id="sess_abc",
        action_type="data_deletion",
        description="2023년 이전 건강 데이터 삭제",
        risk_level=RiskLevel.CRITICAL,
        tool_name="delete_user_data",
        parameters={"before_date": "2023-01-01"},
        impact_summary="약 500개의 건강 기록이 영구 삭제됩니다."
    )
    
    print(f"Action Status: {action.status}")
