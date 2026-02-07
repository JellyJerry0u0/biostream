# BioStream MCP Server - 엔터프라이즈급 보안 시스템

AI 에이전트를 위한 안전하고 규정 준수가 가능한 Model Context Protocol 서버

[![Security](https://img.shields.io/badge/security-enterprise-green)](SECURITY.md)
[![Python](https://img.shields.io/badge/python-3.9+-blue)](https://python.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

## 🔒 핵심 보안 기능

### 1️⃣ 위임 기반 인증 (Delegated Security)
- **OAuth 2.1**: Short-lived Access Token (15분 유효기간)
- **RBAC**: 역할 기반 권한 제어 (FREE/PREMIUM/ADMIN)
- **ABAC**: 속성 기반 세밀한 권한 제어

### 2️⃣ 데이터 프라이버시 보호
- **PII 자동 마스킹**: 이메일, 전화번호, SSN 등 실시간 마스킹
- **데이터 최소화**: 목적별로 필요한 데이터만 전달
- **E2E 암호화**: TLS 1.3 + AES-256

### 3️⃣ 완전한 투명성
- **Immutable Audit Log**: 모든 AI 활동 기록
- **이상 징후 탐지**: 실시간 위험 행동 감지 및 차단
- **SIEM 통합 가능**: 표준 로그 포맷

### 4️⃣ 사용자 중심 제어
- **Explicit Consent**: 명시적 동의 UI
- **Human-in-the-Loop**: 고위험 작업 사전 승인
- **동의 관리**: 언제든 동의 철회 가능

### 5️⃣ AI 안전성 보장
- **Semantic Guardrails**: AI의 도구 오용 방지
- **Pydantic 검증**: 엄격한 타입 및 범위 검증
- **Sandboxing**: 격리된 환경에서 외부 API 실행

## 📁 프로젝트 구조

```
mcp_server/
├── security/                    # 🔐 보안 모듈
│   ├── __init__.py             # 통합 인터페이스
│   ├── auth.py                 # OAuth 2.1, RBAC, ABAC
│   ├── data_protection.py      # PII 마스킹, 암호화
│   ├── audit.py                # 감사 로그, 이상 탐지
│   ├── consent.py              # 동의 관리, HITL
│   └── guardrails.py           # 도구 검증, Guardrails
│
├── tools/                       # 🛠️ MCP 도구
│   ├── db_tools.py             # 데이터베이스 도구
│   └── rag_tools.py            # RAG 도구
│
├── examples/                    # 📚 사용 예시
│   └── security_examples.py    # 보안 기능 예시 코드
│
├── logs/                        # 📝 로그 저장소
│   └── audit.log               # 감사 로그
│
├── server.py                    # 기본 MCP 서버
├── server_secure.py            # ⭐ 보안 통합 서버
├── requirements.txt            # Python 의존성
├── .env.example                # 환경 변수 예시
│
├── SECURITY.md                 # 🔒 보안 가이드
├── ARCHITECTURE.md             # 🏗️ 아키텍처 문서
└── README.md                   # 📖 이 문서
```

## 🚀 빠른 시작

### 1. 설치

```bash
# 저장소 클론
git clone https://github.com/yourusername/biostream.git
cd biostream/backend/mcp_server

# 가상 환경 생성 (권장)
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 의존성 설치
pip install -r requirements.txt
```

### 2. 환경 설정

```bash
# .env 파일 생성
cp .env.example .env

# 시크릿 키 생성 (Python으로)
python -c "import secrets; print(secrets.token_urlsafe(32))"
# 출력된 키를 .env 파일의 MCP_SECRET_KEY에 설정
```

### 3. 서버 실행

```bash
# 보안 서버 실행
python server_secure.py
```

### 4. 테스트

```bash
# 보안 기능 예시 실행
python examples/security_examples.py
```

## 📖 사용 예시

### 기본 도구 호출 (자동 보안 적용)

```python
from server_secure import get_user_health_report

# 모든 보안 계층이 자동으로 적용됩니다
result = await get_user_health_report(
    user_id=123,
    days=7,
    include_summary=True
)

print(result)
# {
#   "status": "success",
#   "data": {
#     "sleep_hours_avg": 7.2,
#     "sleep_quality_avg": 72.5,
#     "protection_applied": true
#   },
#   "security": {
#     "pii_masked": true,
#     "data_minimized": true,
#     "consent_verified": true
#   }
# }
```

### 토큰 생성 및 인증

```python
from security import SecurityManager, UserRole, Scope

security = SecurityManager(secret_key="your-secret-key")

# 액세스 토큰 생성
token = security.token_validator.create_access_token(
    user_id="user123",
    role=UserRole.PREMIUM,
    scopes=[Scope.HEALTH_READ, Scope.LIFESTYLE_ANALYZE]
)

# 인증 및 권한 확인
access_context = await security.authenticate_and_authorize(
    token=token,
    required_scope=Scope.HEALTH_READ
)
```

### PII 마스킹

```python
from security import PIIMasker

masker = PIIMasker()

text = "사용자: hong@example.com, 전화: 010-1234-5678"
masked = masker.mask_text(text)
# "사용자: h***@example.com, 전화: 010-****-5678"
```

### 감사 로그 조회

```python
# 사용자 활동 요약
summary = await get_audit_summary(
    user_id="user123",
    hours=24
)
# {
#   "total_events": 150,
#   "tool_calls": {"get_health_data": 120, "analyze_sleep": 30},
#   "security_violations": 0
# }
```

## 🔍 보안 플로우

```
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
7. PII 마스킹 + 데이터 최소화
   ↓
8. 감사 로그 기록
   ↓
9. 보안 처리된 응답 반환
```

자세한 내용은 [ARCHITECTURE.md](ARCHITECTURE.md)를 참조하세요.

## 🛡️ 보안 원칙

### 1. 최소 권한 (Least Privilege)
- 필요한 데이터만 접근
- 역할별 최소 권한 부여
- 시간 제한된 토큰

### 2. 명시적 동의 (Explicit Consent)
- 모든 데이터 접근 전 동의 요청
- 동의 내역 추적 가능
- 언제든 철회 가능

### 3. 투명성 (Transparency)
- 모든 AI 활동 기록
- 사용자에게 활동 내역 제공
- 감사 가능한 로그

### 4. 방어 심층화 (Defense in Depth)
- 다중 보안 계층
- 각 계층 독립 동작
- 하나 실패해도 다른 계층 보호

### 5. 사용자 제어 (User Control)
- Human-in-the-Loop
- 고위험 작업 사전 승인
- 실시간 모니터링

## 📊 성능 및 확장성

### 처리 성능
- **요청 처리**: ~50ms (보안 계층 포함)
- **PII 마스킹**: ~5ms
- **감사 로깅**: 비동기 처리 (차단 없음)

### 확장성
- **수평 확장**: 무상태 서버 (Redis 세션)
- **수직 확장**: 멀티스레드 지원
- **로드 밸런싱**: Nginx/HAProxy 지원

### 리소스 사용량
- **메모리**: ~200MB (베이스)
- **CPU**: 낮음 (I/O 바운드)
- **스토리지**: 감사 로그 (로테이션 권장)

## 🔧 설정

### 환경 변수

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `MCP_SECRET_KEY` | JWT 서명 키 | 필수 |
| `MCP_ENCRYPTION_KEY` | 암호화 키 | 필수 |
| `DATABASE_URL` | 데이터베이스 URL | - |
| `LOG_LEVEL` | 로그 레벨 | INFO |
| `RATE_LIMIT_REQUESTS_PER_MINUTE` | 분당 요청 제한 | 30 |

자세한 설정은 [.env.example](.env.example)을 참조하세요.

### 보안 설정

```python
# server_secure.py 또는 설정 파일에서

# 자동 동의 승인 (개발 환경만)
AUTO_APPROVE_LOW_RISK = False  # 프로덕션: False

# 토큰 유효 기간
TOKEN_EXPIRY_MINUTES = 15  # 15분

# 속도 제한
RATE_LIMIT_PER_MINUTE = 30  # 분당 30회

# 이상 징후 감지 임계값
ANOMALY_THRESHOLD_REQUESTS = 30  # 분당 30회 초과 시 경고
```

## 📚 문서

- [SECURITY.md](SECURITY.md) - 보안 가이드 및 체크리스트
- [ARCHITECTURE.md](ARCHITECTURE.md) - 아키텍처 다이어그램
- [examples/](examples/) - 코드 예시

## 🧪 테스트

```bash
# 단위 테스트
pytest tests/

# 보안 테스트
python tests/security_test.py

# 통합 테스트
python tests/integration_test.py
```

## 📈 모니터링

### 로그 수준

- **DEBUG**: 상세한 디버그 정보
- **INFO**: 정상 작동 정보
- **WARNING**: 잠재적 문제 (이상 징후)
- **ERROR**: 오류 발생
- **CRITICAL**: 심각한 보안 위반

### 감사 로그 분석

```bash
# 최근 보안 이벤트 조회
grep "SECURITY_VIOLATION" logs/audit.log

# 사용자별 활동 분석
grep "user123" logs/audit.log | wc -l

# 도구 사용 통계
grep "TOOL_CALL" logs/audit.log | cut -d':' -f3 | sort | uniq -c
```

## 🤝 기여

보안 이슈 발견 시:
1. **공개하지 마세요** - GitHub Issues 사용 금지
2. security@biostream.com으로 비공개 보고
3. 24시간 내 응답 보장

일반 기여:
1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Open Pull Request

## 📝 라이선스

MIT License - 자세한 내용은 [LICENSE](LICENSE) 참조

## 🙏 감사

이 프로젝트는 다음 보안 원칙과 표준을 따릅니다:
- OWASP Top 10
- GDPR 개인정보 보호
- NIST Cybersecurity Framework
- OAuth 2.1 표준
- MCP Protocol 사양

## 📞 지원

- 📧 이메일: support@biostream.com
- 💬 Discord: [BioStream Community](https://discord.gg/biostream)
- 📖 문서: [docs.biostream.com](https://docs.biostream.com)
- 🐛 버그 리포트: [GitHub Issues](https://github.com/yourusername/biostream/issues)

---

**⚠️ 중요**: 프로덕션 환경에서는 반드시:
- 강력한 시크릿 키 사용
- TLS/HTTPS 활성화
- 정기적인 보안 감사
- 로그 백업 및 모니터링
- 침입 탐지 시스템 (IDS) 연동

**Built with ❤️ for a safer AI future**
