"""
보안 시스템 사용 예시
"""
import asyncio
from datetime import datetime


async def example_1_basic_authentication():
    """예시 1: 기본 인증 및 권한 확인"""
    print("=" * 60)
    print("예시 1: OAuth 2.1 인증 및 RBAC/ABAC 권한 확인")
    print("=" * 60)
    
    from security.auth import SecurityManager, UserRole, Scope
    
    # SecurityManager 초기화
    security_manager = SecurityManager(secret_key="example-secret-key")
    
    # 액세스 토큰 생성
    token = security_manager.token_validator.create_access_token(
        user_id="user123",
        role=UserRole.PREMIUM,
        scopes=[Scope.HEALTH_READ, Scope.LIFESTYLE_ANALYZE],
        attributes={
            "is_owner": True,
            "requested_user_id": "user123",
            "hour": 14  # 오후 2시
        }
    )
    
    print(f"✓ 액세스 토큰 생성: {token[:50]}...")
    
    # 인증 및 권한 부여
    try:
        access_context = await security_manager.authenticate_and_authorize(
            token=token,
            required_scope=Scope.HEALTH_READ,
            context_attributes={"requested_user_id": "user123"}
        )
        
        print(f"✓ 인증 성공: user_id={access_context.user_id}")
        print(f"✓ 역할: {access_context.role}")
        print(f"✓ 스코프: {access_context.scopes}")
        print(f"✓ RBAC/ABAC 검증 통과")
        
    except Exception as e:
        print(f"✗ 인증 실패: {str(e)}")
    
    print()


async def example_2_pii_masking():
    """예시 2: PII 마스킹"""
    print("=" * 60)
    print("예시 2: 개인정보 마스킹")
    print("=" * 60)
    
    from security.data_protection import PIIMasker
    
    masker = PIIMasker()
    
    # 테스트 데이터
    sample_text = """
    사용자 정보:
    이름: 홍길동
    이메일: hong@example.com
    전화번호: 010-1234-5678
    주소: 서울시 강남구
    """
    
    print("원본 데이터:")
    print(sample_text)
    
    # 마스킹 처리
    masked_text = masker.mask_text(sample_text)
    
    print("\n마스킹된 데이터:")
    print(masked_text)
    print()


async def example_3_data_minimization():
    """예시 3: 데이터 최소화"""
    print("=" * 60)
    print("예시 3: 데이터 최소화 및 요약")
    print("=" * 60)
    
    from security.data_protection import DataMinimizer
    
    minimizer = DataMinimizer()
    
    # 샘플 데이터
    sample_data = [
        {
            "user_id": 123,
            "name": "홍길동",
            "email": "hong@example.com",
            "sleep_hours": 7.5,
            "sleep_quality_score": 75,
            "bedtime": "23:30",
            "smoking": False,  # 불필요한 정보
            "date": "2026-02-01"
        },
        {
            "user_id": 123,
            "name": "홍길동",
            "email": "hong@example.com",
            "sleep_hours": 6.5,
            "sleep_quality_score": 60,
            "bedtime": "00:15",
            "smoking": False,
            "date": "2026-02-02"
        }
    ]
    
    print(f"원본 데이터: {len(sample_data)}개 레코드")
    
    # 데이터 최소화
    minimized = minimizer.minimize(
        data=sample_data,
        purpose="sleep_analysis"
    )
    
    print(f"\n최소화된 데이터: {len(minimized)}개 레코드")
    print("허용된 필드:", list(minimized[0].keys()) if minimized else [])
    
    # 데이터 요약
    summary = minimizer.summarize(
        data=sample_data,
        summary_fields={
            "sleep_hours": "avg",
            "sleep_quality_score": "avg"
        }
    )
    
    print("\n요약 데이터:")
    for key, value in summary.items():
        print(f"  {key}: {value}")
    
    print()


async def example_4_audit_logging():
    """예시 4: 감사 로깅 및 이상 징후 탐지"""
    print("=" * 60)
    print("예시 4: 감사 로깅 및 이상 징후 탐지")
    print("=" * 60)
    
    from security.audit import AuditLogger, AnomalyDetector, EventType, EventSeverity, AuditEvent
    
    # 감사 로거 초기화
    audit_logger = AuditLogger()
    
    # Tool Call 기록
    audit_logger.log_tool_call(
        user_id="user123",
        tool_name="get_health_data",
        parameters={"days": 7},
        result="success",
        session_id="sess_abc"
    )
    
    print("✓ Tool Call 기록 완료")
    
    # 이상 징후 탐지기 초기화
    anomaly_detector = AnomalyDetector(audit_logger)
    
    # 정상 요청 시뮬레이션
    for i in range(5):
        event = AuditEvent(
            event_id="",
            event_type=EventType.TOOL_CALL,
            severity=EventSeverity.INFO,
            user_id="user123",
            session_id="sess_abc",
            action="call_tool:get_health_data",
            tool_name="get_health_data",
            result="success"
        )
        
        anomaly = anomaly_detector.check_anomaly(
            user_id="user123",
            session_id="sess_abc",
            event=event
        )
        
        if anomaly:
            print(f"⚠ 이상 징후 감지: {anomaly}")
        else:
            print(f"✓ 정상 요청 {i+1}")
    
    # 활동 요약 조회
    summary = audit_logger.get_summary("user123")
    print(f"\n사용자 활동 요약:")
    print(f"  총 이벤트: {summary['total_events']}")
    print(f"  Tool Call 횟수: {dict(summary['tool_calls'])}")
    
    print()


async def example_5_consent_management():
    """예시 5: 사용자 동의 관리"""
    print("=" * 60)
    print("예시 5: 사용자 동의 관리")
    print("=" * 60)
    
    from security.consent import ConsentManager, ConsentScope, RiskLevel
    
    consent_manager = ConsentManager()
    
    # 동의 요청 (저위험, 자동 승인)
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
    
    print(f"동의 요청 ID: {consent_request.request_id}")
    print(f"상태: {consent_request.status}")
    
    if consent_request.status == "granted":
        print("✓ 동의 자동 승인됨")
    
    # 유효한 동의 확인
    has_consent = consent_manager.has_valid_consent(
        user_id="user123",
        scope=ConsentScope.READ_HEALTH_DATA
    )
    
    print(f"유효한 동의 존재: {has_consent}")
    
    # 동의 철회
    revoked = consent_manager.revoke_consent(
        user_id="user123",
        scope=ConsentScope.READ_HEALTH_DATA
    )
    
    if revoked:
        print("✓ 동의 철회 완료")
    
    print()


async def example_6_human_in_the_loop():
    """예시 6: Human-in-the-Loop 검증"""
    print("=" * 60)
    print("예시 6: Human-in-the-Loop 고위험 작업 검증")
    print("=" * 60)
    
    from security.consent import HumanInTheLoopValidator, RiskLevel
    
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
    
    print(f"작업 승인 요청 ID: {action.action_id}")
    print(f"위험 수준: {action.risk_level}")
    print(f"영향: {action.impact_summary}")
    print(f"상태: {action.status}")
    
    # 사용자가 승인하는 시뮬레이션
    confirmed = hitl.confirm_action(action.action_id)
    
    if confirmed:
        print("✓ 사용자가 작업을 승인했습니다")
        print("  → 이제 AI가 작업을 수행할 수 있습니다")
    else:
        print("✗ 승인 실패")
    
    print()


async def example_7_guardrails():
    """예시 7: Semantic Guardrails"""
    print("=" * 60)
    print("예시 7: Semantic Guardrails 및 도구 검증")
    print("=" * 60)
    
    from security.guardrails import (
        SemanticGuardrails, 
        ToolValidator, 
        ToolMetadata,
        ToolCategory,
        ToolRiskLevel,
        GuardrailViolation
    )
    from pydantic import BaseModel, Field
    
    # Pydantic 스키마 정의
    class GetDataParams(BaseModel):
        user_id: int = Field(..., gt=0)
        days: int = Field(7, ge=1, le=30)
    
    # 도구 함수
    def get_data(user_id: int, days: int):
        return {"user_id": user_id, "days": days, "data": ["mock"]}
    
    # ToolValidator 초기화
    validator = ToolValidator()
    
    # 도구 등록
    validator.register_tool(
        name="get_data",
        description="데이터 조회",
        metadata=ToolMetadata(
            name="get_data",
            category=ToolCategory.DATA_READ,
            risk_level=ToolRiskLevel.LOW,
            description="데이터 조회",
            required_scopes={"health:read"}
        ),
        parameter_schema=GetDataParams,
        function=get_data
    )
    
    # Guardrail 추가
    validator.guardrails.add_constraint(
        tool_name="get_data",
        constraint_fn=lambda p: p.get("days", 0) <= 30,
        error_message="30일 이상 조회 불가"
    )
    
    # 정상 요청
    try:
        result = validator.validate_and_execute(
            tool_name="get_data",
            parameters={"user_id": 123, "days": 7}
        )
        print(f"✓ 도구 실행 성공: {result}")
    except Exception as e:
        print(f"✗ 실행 실패: {str(e)}")
    
    # 제약 조건 위반
    try:
        result = validator.validate_and_execute(
            tool_name="get_data",
            parameters={"user_id": 123, "days": 100}  # 30일 초과
        )
    except GuardrailViolation as e:
        print(f"✓ Guardrail이 위반을 차단: {str(e)}")
    except Exception as e:
        print(f"✓ 검증 실패: {str(e)}")
    
    print()


async def example_8_full_pipeline():
    """예시 8: 전체 보안 파이프라인"""
    print("=" * 60)
    print("예시 8: 전체 보안 파이프라인 통합")
    print("=" * 60)
    
    from security.data_protection import DataProtectionPipeline, PIIMasker, DataMinimizer, EncryptionManager
    
    # 파이프라인 초기화
    pipeline = DataProtectionPipeline(
        pii_masker=PIIMasker(),
        data_minimizer=DataMinimizer(),
        encryption_manager=EncryptionManager("secret-key")
    )
    
    # 샘플 데이터
    sample_data = [
        {
            "user_id": 123,
            "name": "홍길동",
            "email": "hong@example.com",
            "phone": "010-1234-5678",
            "sleep_hours": 7.5,
            "sleep_quality_score": 75,
            "date": "2026-02-01"
        }
    ]
    
    print("원본 데이터:")
    print(f"  이름: {sample_data[0]['name']}")
    print(f"  이메일: {sample_data[0]['email']}")
    print(f"  전화: {sample_data[0]['phone']}")
    
    # 데이터 보호 처리
    protected = pipeline.process_for_llm(
        data=sample_data,
        purpose="sleep_analysis",
        sensitive_keys={"name", "email", "phone"},
        summarize=True,
        summary_fields={"sleep_hours": "avg", "sleep_quality_score": "avg"}
    )
    
    print("\n보호 처리된 데이터:")
    print(f"  목적: {protected['purpose']}")
    print(f"  보호 적용: {protected['protection_applied']}")
    print(f"  요약 데이터: {protected}")
    
    print()


async def main():
    """모든 예시 실행"""
    print("\n")
    print("╔" + "=" * 58 + "╗")
    print("║" + " " * 10 + "BioStream MCP 보안 시스템 예시" + " " * 17 + "║")
    print("╚" + "=" * 58 + "╝")
    print("\n")
    
    await example_1_basic_authentication()
    await example_2_pii_masking()
    await example_3_data_minimization()
    await example_4_audit_logging()
    await example_5_consent_management()
    await example_6_human_in_the_loop()
    await example_7_guardrails()
    await example_8_full_pipeline()
    
    print("=" * 60)
    print("모든 예시 실행 완료!")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
