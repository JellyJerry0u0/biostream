"""
감사 및 모니터링 시스템 (Audit & Monitoring)
AI Tool Call에 대한 투명한 기록 및 이상 징후 탐지
"""
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from enum import Enum
from pydantic import BaseModel, Field
import json
import logging
from collections import defaultdict, deque

logger = logging.getLogger(__name__)


# ==================== 감사 로그 모델 ====================

class EventType(str, Enum):
    """이벤트 타입"""
    TOOL_CALL = "tool_call"
    AUTHENTICATION = "authentication"
    AUTHORIZATION = "authorization"
    DATA_ACCESS = "data_access"
    DATA_MODIFICATION = "data_modification"
    CONSENT_REQUEST = "consent_request"
    CONSENT_GRANTED = "consent_granted"
    CONSENT_DENIED = "consent_denied"
    SECURITY_VIOLATION = "security_violation"
    ANOMALY_DETECTED = "anomaly_detected"


class EventSeverity(str, Enum):
    """이벤트 심각도"""
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


class AuditEvent(BaseModel):
    """감사 이벤트"""
    event_id: str  # 고유 이벤트 ID
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    event_type: EventType
    severity: EventSeverity
    
    # 주체 정보
    user_id: str
    session_id: Optional[str] = None
    ip_address: Optional[str] = None
    
    # 이벤트 상세
    action: str  # 수행된 작업
    resource: Optional[str] = None  # 접근한 리소스
    tool_name: Optional[str] = None  # 호출한 도구 이름
    parameters: Optional[Dict[str, Any]] = None  # 전달한 파라미터
    result: Optional[str] = None  # 결과 상태 (success, failure, denied)
    
    # 메타데이터
    metadata: Dict[str, Any] = Field(default_factory=dict)
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


# ==================== Immutable Audit Logger ====================

class AuditLogger:
    """
    불변 감사 로그 시스템
    모든 Tool Call 및 보안 이벤트를 기록합니다.
    """
    
    def __init__(self, storage_path: Optional[str] = None):
        """
        Args:
            storage_path: 로그 파일 경로 (None이면 메모리에만 저장)
        """
        self.storage_path = storage_path
        self.events: List[AuditEvent] = []  # 메모리 버퍼
        self._event_counter = 0
    
    def log_event(self, event: AuditEvent) -> str:
        """
        이벤트 기록
        
        Returns:
            event_id: 기록된 이벤트 ID
        """
        # 이벤트 ID 생성
        if not event.event_id:
            self._event_counter += 1
            event.event_id = f"evt_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}_{self._event_counter:06d}"
        
        # 메모리에 저장
        self.events.append(event)
        
        # 파일에 추가 (append-only)
        if self.storage_path:
            try:
                with open(self.storage_path, 'a', encoding='utf-8') as f:
                    f.write(event.model_dump_json() + '\n')
            except Exception as e:
                logger.error(f"Failed to write audit log: {str(e)}")
        
        # 로깅
        log_level = {
            EventSeverity.DEBUG: logging.DEBUG,
            EventSeverity.INFO: logging.INFO,
            EventSeverity.WARNING: logging.WARNING,
            EventSeverity.ERROR: logging.ERROR,
            EventSeverity.CRITICAL: logging.CRITICAL,
        }.get(event.severity, logging.INFO)
        
        logger.log(
            log_level,
            f"AUDIT [{event.event_type}] {event.action} by {event.user_id} - {event.result}"
        )
        
        return event.event_id
    
    def log_tool_call(
        self,
        user_id: str,
        tool_name: str,
        parameters: Dict[str, Any],
        result: str,
        session_id: Optional[str] = None,
        ip_address: Optional[str] = None
    ) -> str:
        """Tool Call 기록"""
        event = AuditEvent(
            event_id="",
            event_type=EventType.TOOL_CALL,
            severity=EventSeverity.INFO,
            user_id=user_id,
            session_id=session_id,
            ip_address=ip_address,
            action=f"call_tool:{tool_name}",
            tool_name=tool_name,
            parameters=parameters,
            result=result
        )
        return self.log_event(event)
    
    def log_security_violation(
        self,
        user_id: str,
        violation_type: str,
        details: Dict[str, Any],
        session_id: Optional[str] = None
    ) -> str:
        """보안 위반 기록"""
        event = AuditEvent(
            event_id="",
            event_type=EventType.SECURITY_VIOLATION,
            severity=EventSeverity.CRITICAL,
            user_id=user_id,
            session_id=session_id,
            action=f"security_violation:{violation_type}",
            result="blocked",
            metadata=details
        )
        return self.log_event(event)
    
    def query_events(
        self,
        user_id: Optional[str] = None,
        event_type: Optional[EventType] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        limit: int = 100
    ) -> List[AuditEvent]:
        """감사 로그 조회"""
        filtered_events = self.events
        
        if user_id:
            filtered_events = [e for e in filtered_events if e.user_id == user_id]
        
        if event_type:
            filtered_events = [e for e in filtered_events if e.event_type == event_type]
        
        if start_time:
            filtered_events = [e for e in filtered_events if e.timestamp >= start_time]
        
        if end_time:
            filtered_events = [e for e in filtered_events if e.timestamp <= end_time]
        
        # 최신순 정렬
        filtered_events.sort(key=lambda e: e.timestamp, reverse=True)
        
        return filtered_events[:limit]
    
    def get_summary(self, user_id: str, time_window: timedelta = timedelta(hours=1)) -> Dict[str, Any]:
        """사용자의 최근 활동 요약"""
        start_time = datetime.utcnow() - time_window
        recent_events = self.query_events(user_id=user_id, start_time=start_time)
        
        summary = {
            "user_id": user_id,
            "time_window": str(time_window),
            "total_events": len(recent_events),
            "event_types": defaultdict(int),
            "tool_calls": defaultdict(int),
            "security_violations": 0
        }
        
        for event in recent_events:
            summary["event_types"][event.event_type] += 1
            
            if event.event_type == EventType.TOOL_CALL:
                summary["tool_calls"][event.tool_name] += 1
            
            if event.event_type == EventType.SECURITY_VIOLATION:
                summary["security_violations"] += 1
        
        return dict(summary)


# ==================== 이상 징후 탐지 ====================

class AnomalyRule(BaseModel):
    """이상 징후 탐지 규칙"""
    name: str
    description: str
    threshold: Dict[str, Any]
    action: str  # "alert" or "block"


class AnomalyDetector:
    """
    이상 징후 탐지기
    과도한 데이터 요청, 권한 외 도구 호출 등을 실시간 탐지합니다.
    """
    
    def __init__(self, audit_logger: AuditLogger):
        self.audit_logger = audit_logger
        self.rules = self._load_default_rules()
        
        # 사용자별 활동 추적 (시간 윈도우)
        self.user_activity: Dict[str, deque] = defaultdict(lambda: deque(maxlen=1000))
        
        # 차단된 세션
        self.blocked_sessions: Set[str] = set()
    
    def _load_default_rules(self) -> List[AnomalyRule]:
        """기본 이상 징후 탐지 규칙"""
        return [
            AnomalyRule(
                name="excessive_data_requests",
                description="짧은 시간 내 과도한 데이터 요청",
                threshold={"requests_per_minute": 30, "time_window": 60},
                action="alert"
            ),
            AnomalyRule(
                name="mass_data_exfiltration",
                description="대량 데이터 추출 시도",
                threshold={"data_volume_mb": 10, "time_window": 300},
                action="block"
            ),
            AnomalyRule(
                name="unauthorized_tool_access",
                description="권한 외 도구 접근 시도",
                threshold={"denied_attempts": 3, "time_window": 60},
                action="block"
            ),
            AnomalyRule(
                name="rapid_permission_escalation",
                description="빠른 권한 상승 시도",
                threshold={"escalation_attempts": 5, "time_window": 300},
                action="alert"
            ),
            AnomalyRule(
                name="off_hours_access",
                description="비정상 시간대 접근",
                threshold={"hour_start": 2, "hour_end": 5},
                action="alert"
            ),
        ]
    
    def check_anomaly(
        self,
        user_id: str,
        session_id: str,
        event: AuditEvent
    ) -> Optional[Dict[str, Any]]:
        """
        이상 징후 확인
        
        Returns:
            이상 징후가 감지되면 상세 정보 반환, 없으면 None
        """
        # 차단된 세션 확인
        if session_id in self.blocked_sessions:
            return {
                "anomaly": "blocked_session",
                "action": "block",
                "reason": "Session has been blocked due to security violations"
            }
        
        # 사용자 활동 기록
        self.user_activity[user_id].append({
            "timestamp": event.timestamp,
            "event": event
        })
        
        # 각 규칙 검사
        for rule in self.rules:
            anomaly = self._check_rule(user_id, session_id, event, rule)
            if anomaly:
                # 감사 로그 기록
                self.audit_logger.log_event(AuditEvent(
                    event_id="",
                    event_type=EventType.ANOMALY_DETECTED,
                    severity=EventSeverity.WARNING if rule.action == "alert" else EventSeverity.CRITICAL,
                    user_id=user_id,
                    session_id=session_id,
                    action=f"anomaly:{rule.name}",
                    result=rule.action,
                    metadata=anomaly
                ))
                
                # 차단 액션
                if rule.action == "block":
                    self.block_session(session_id, rule.name)
                
                return anomaly
        
        return None
    
    def _check_rule(
        self,
        user_id: str,
        session_id: str,
        event: AuditEvent,
        rule: AnomalyRule
    ) -> Optional[Dict[str, Any]]:
        """개별 규칙 검사"""
        if rule.name == "excessive_data_requests":
            return self._check_rate_limit(
                user_id,
                requests_per_minute=rule.threshold["requests_per_minute"],
                time_window=rule.threshold["time_window"]
            )
        
        elif rule.name == "unauthorized_tool_access":
            if event.event_type == EventType.AUTHORIZATION and event.result == "denied":
                return self._check_denied_attempts(
                    user_id,
                    max_attempts=rule.threshold["denied_attempts"],
                    time_window=rule.threshold["time_window"]
                )
        
        elif rule.name == "off_hours_access":
            current_hour = datetime.utcnow().hour
            if rule.threshold["hour_start"] <= current_hour < rule.threshold["hour_end"]:
                return {
                    "rule": rule.name,
                    "reason": f"Access during off-hours: {current_hour}:00",
                    "action": rule.action
                }
        
        return None
    
    def _check_rate_limit(
        self,
        user_id: str,
        requests_per_minute: int,
        time_window: int
    ) -> Optional[Dict[str, Any]]:
        """속도 제한 확인"""
        cutoff_time = datetime.utcnow() - timedelta(seconds=time_window)
        recent_events = [
            activity for activity in self.user_activity[user_id]
            if activity["timestamp"] >= cutoff_time
        ]
        
        if len(recent_events) > requests_per_minute:
            return {
                "rule": "excessive_data_requests",
                "reason": f"{len(recent_events)} requests in {time_window}s (limit: {requests_per_minute})",
                "action": "alert"
            }
        
        return None
    
    def _check_denied_attempts(
        self,
        user_id: str,
        max_attempts: int,
        time_window: int
    ) -> Optional[Dict[str, Any]]:
        """거부된 접근 시도 확인"""
        cutoff_time = datetime.utcnow() - timedelta(seconds=time_window)
        denied_events = [
            activity for activity in self.user_activity[user_id]
            if activity["timestamp"] >= cutoff_time
            and activity["event"].result == "denied"
        ]
        
        if len(denied_events) >= max_attempts:
            return {
                "rule": "unauthorized_tool_access",
                "reason": f"{len(denied_events)} denied attempts in {time_window}s",
                "action": "block"
            }
        
        return None
    
    def block_session(self, session_id: str, reason: str):
        """세션 차단"""
        self.blocked_sessions.add(session_id)
        logger.critical(f"Session blocked: {session_id}, reason: {reason}")
    
    def unblock_session(self, session_id: str):
        """세션 차단 해제 (관리자만)"""
        self.blocked_sessions.discard(session_id)
        logger.info(f"Session unblocked: {session_id}")


# ==================== 사용 예시 ====================

if __name__ == "__main__":
    # 감사 로거 초기화
    audit_logger = AuditLogger(storage_path="audit.log")
    
    # 이상 징후 탐지기 초기화
    anomaly_detector = AnomalyDetector(audit_logger)
    
    # Tool Call 기록
    audit_logger.log_tool_call(
        user_id="user123",
        tool_name="get_user_health_report",
        parameters={"user_id": 123},
        result="success",
        session_id="sess_abc123"
    )
    
    # 활동 요약 조회
    summary = audit_logger.get_summary("user123")
    print(json.dumps(summary, indent=2))
