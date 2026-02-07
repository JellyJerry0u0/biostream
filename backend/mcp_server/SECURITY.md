# BioStream MCP Server - 보안 시스템

이 MCP 서버는 포괄적인 보안 체계를 구현하여 AI 에이전트의 안전한 데이터 접근을 보장합니다.

## 보안 아키텍처

### 1. 인증 및 권한 부여 (Authentication & Authorization)

#### OAuth 2.1 통합
- **Short-lived Access Token**: 15분 유효기간의 액세스 토큰
- **Delegated Security**: LLM 에이전트에게 특정 스코프만 위임
- **Token Revocation**: 토큰 폐기 메커니즘

#### RBAC (Role-Based Access Control)
- **FREE**: 읽기 권한만 (health:read, lifestyle:read, profile:read)
- **PREMIUM**: 읽기 + 쓰기 + 분석 권한
- **ADMIN**: 모든 권한

#### ABAC (Attribute-Based Access Control)
- 본인 데이터만 조회 가능
- 야간 시간대(23:00-06:00) 접근 제한
- 속도 제한 확인
- 민감 데이터는 프리미엄 사용자만

### 2. 데이터 보호 계층 (Data Protection)

#### PII 마스킹
- **이메일**: user@example.com → u***@example.com
- **전화번호**: 010-1234-5678 → 010-****-5678
- **정규표현식 기반**: SSN, 신용카드, IP 주소 등 자동 탐지

#### 데이터 최소화 (Least Privilege)
- **목적별 정책**: 수면 분석 시 수면 데이터만 전달
- **시간 범위 제한**: 최근 N일 데이터만
- **레코드 수 제한**: 최대 레코드 수 설정

#### 데이터 요약 및 점수화
- 원본 대신 집계 데이터 제공 (평균, 합계, 최소/최대)
- 프라이버시 침해 최소화

#### 암호화 (E2EE)
- **전송**: TLS 1.3 필수
- **저장**: AES-256 암호화
- **해싱**: SHA-256 기반 식별자 해싱

### 3. 감사 및 모니터링 (Audit & Monitoring)

#### Immutable Audit Log
- **Append-only**: 쓰기 전용 로그 저장소
- **모든 Tool Call 기록**: 도구명, 파라미터, 결과, 타임스탬프
- **보안 이벤트 추적**: 인증, 권한 부여, 위반 시도

#### 이상 징후 탐지
- **과도한 요청**: 분당 30회 이상
- **대량 데이터 추출**: 5분 내 10MB 이상
- **권한 외 접근**: 3회 이상 거부 시 세션 차단
- **야간 접근**: 새벽 2-5시 접근 경고
- **자동 차단**: 위험 행동 감지 시 즉시 세션 차단

### 4. 사용자 동의 및 제어 (User Consent)

#### Explicit Consent
- **명시적 승인 UI**: "AI가 최근 7일 수면 기록을 읽으려 합니다. 허용하시겠습니까?"
- **자동 승인**: 저위험 작업(읽기 전용)은 자동 승인 가능
- **동의 기록**: 모든 동의 내역 저장 및 추적

#### Human-in-the-Loop
- **고위험 작업 확인**: 데이터 삭제, 건강 조언 실행 등
- **최종 사용자 컨펌**: AI가 독단적으로 수행 불가
- **영향 요약 제공**: "500개의 기록이 영구 삭제됩니다"

### 5. 도구 항정성 (Tool Guardrails)

#### Semantic Guardrails
- **제약 조건 정의**: "30일 이상 데이터 조회 불가"
- **파라미터 검증**: 타입, 범위, 선택지 확인
- **오용 방지**: LLM의 도구 오해 차단

#### Pydantic 스키마 검증
- **엄격한 타입 체크**: 모든 파라미터 타입 검증
- **유효성 검사**: 범위, 필수 여부, 패턴 검증
- **자동 에러 처리**: 잘못된 입력 즉시 거부

#### Sandboxing
- **격리 실행**: 외부 API 호출 도구는 샌드박스에서 실행
- **네트워크 제한**: 필요 시에만 네트워크 접근 허용
- **사이드 이펙트 차단**: 시스템 영향 최소화

## 파일 구조

```
mcp_server/
├── security/
│   ├── __init__.py          # 보안 모듈 통합 인터페이스
│   ├── auth.py              # OAuth 2.1, RBAC, ABAC
│   ├── data_protection.py   # PII 마스킹, 데이터 최소화, 암호화
│   ├── audit.py             # 감사 로그, 이상 징후 탐지
│   ├── consent.py           # 사용자 동의, HITL
│   └── guardrails.py        # Semantic Guardrails, 도구 검증
├── tools/
│   ├── db_tools.py          # 데이터베이스 도구
│   └── rag_tools.py         # RAG 도구
├── server.py                # 기본 MCP 서버
├── server_secure.py         # 보안 통합 MCP 서버 ★
├── requirements.txt
└── logs/
    └── audit.log            # 감사 로그 저장소
```

## 사용 방법

### 1. 의존성 설치

```bash
pip install -r requirements.txt
```

### 2. 환경 변수 설정

```bash
# .env 파일 생성
MCP_SECRET_KEY=your-secret-key-here
MCP_ENCRYPTION_KEY=your-encryption-key-here
```

### 3. 보안 서버 실행

```bash
python server_secure.py
```

### 4. 도구 호출 예시

```python
# 건강 리포트 조회 (자동으로 모든 보안 계층 적용)
result = await get_user_health_report(
    user_id=123,
    days=7,
    include_summary=True
)

# 결과에는 다음이 포함됨:
# - PII 마스킹된 데이터
# - 최소화된 필드
# - 감사 로그 기록
# - 동의 확인 완료
```

## 보안 플로우

```
사용자 요청
    ↓
1. OAuth 토큰 검증
    ↓
2. RBAC/ABAC 권한 확인
    ↓
3. 사용자 동의 확인
    ↓
4. 속도 제한 확인
    ↓
5. 이상 징후 탐지
    ↓
6. 데이터 조회
    ↓
7. PII 마스킹
    ↓
8. 데이터 최소화
    ↓
9. 요약 생성 (선택)
    ↓
10. 감사 로그 기록
    ↓
보안 처리된 응답 반환
```

## 주요 클래스

### SecurityManager
- 통합 보안 관리자
- 인증, 권한 부여 통합 프로세스

### DataProtectionPipeline
- PII 마스킹 → 데이터 최소화 → 요약 순차 처리
- LLM에게 전달하기 전 데이터 보호

### AnomalyDetector
- 실시간 이상 징후 탐지
- 자동 세션 차단

### ConsentManager
- 사용자 동의 관리
- 동의 기록 추적 및 철회

### ToolValidator
- Pydantic 스키마 검증
- Semantic Guardrails 적용

## 환경별 설정

### 개발 환경
```python
SECRET_KEY = "dev-secret-key"
AUTO_APPROVE_CONSENT = True
LOG_LEVEL = "DEBUG"
```

### 프로덕션 환경
```python
SECRET_KEY = os.getenv("MCP_SECRET_KEY")  # 환경 변수 필수
AUTO_APPROVE_CONSENT = False  # 명시적 동의 필수
LOG_LEVEL = "INFO"
ENABLE_TLS = True
```

## 감사 로그 조회

```python
# 사용자 활동 요약
summary = await get_audit_summary(
    user_id="user123",
    hours=1
)

# 출력:
# {
#   "user_id": "user123",
#   "total_events": 45,
#   "event_types": {
#     "tool_call": 40,
#     "authentication": 3,
#     "security_violation": 2
#   },
#   "tool_calls": {
#     "get_user_health_report": 35,
#     "get_sleep_data": 5
#   }
# }
```

## 동의 관리

```python
# 동의 철회
result = await revoke_user_consent(
    user_id="user123",
    scope="read_health_data"
)

# 동의 현황 조회
consents = consent_manager.get_user_consents("user123")
```

## 보안 모니터링

### 실시간 알림
- 이상 징후 감지 시 로그에 CRITICAL 레벨로 기록
- 세션 차단 시 즉시 알림

### 정기 감사
- audit.log 파일 주기적 검토
- 이상 패턴 분석

### 대시보드 (향후 구현)
- 실시간 모니터링 대시보드
- 사용자별 활동 추적
- 보안 이벤트 시각화

## 보안 체크리스트

- [x] OAuth 2.1 토큰 인증
- [x] RBAC 역할 기반 권한
- [x] ABAC 속성 기반 권한
- [x] PII 자동 마스킹
- [x] 데이터 최소화
- [x] 암호화 (전송 & 저장)
- [x] Immutable 감사 로그
- [x] 이상 징후 탐지
- [x] 자동 세션 차단
- [x] 사용자 동의 관리
- [x] Human-in-the-Loop
- [x] Semantic Guardrails
- [x] Pydantic 스키마 검증
- [x] 속도 제한
- [ ] TLS 1.3 인증서 (프로덕션)
- [ ] 샌드박스 실제 구현
- [ ] 모니터링 대시보드

## 문의 및 지원

보안 관련 문의: security@biostream.com
버그 리포트: GitHub Issues
