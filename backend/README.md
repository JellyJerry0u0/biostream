# BioStream Backend

Qdrant 중심 RAG + LangGraph 기반 리포트 오케스트레이션 백엔드

## 아키텍처

- **Qdrant**: 로컬 도커로 실행되는 벡터 DB (기본 URL: http://localhost:6333)
- **LangGraph**: 리포트 생성 워크플로우 오케스트레이션
- **Gemini API**: 임베딩 생성 (gemini-embedding-001, 768차원) 및 LLM 호출
- **FastAPI**: REST API 서버

## 환경 설정

`.env` 파일을 생성하고 다음 환경 변수를 설정하세요:

```env
# Gemini API
GEMINI_API_KEY=your_gemini_api_key_here

# Qdrant
QDRANT_URL=http://localhost:6333
QDRANT_COLLECTION=biostream_corpus_v1

# Embedding
GEMINI_EMBED_MODEL=gemini-embedding-001
EMBED_DIM=768

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/biostream
```

## 설치 및 실행

### 1. 의존성 설치

```bash
cd backend
pip install -r requirements.txt
```

### 2. Qdrant 도커 실행

```bash
docker run -p 6333:6333 -p 6334:6334 qdrant/qdrant
```

또는 `docker-compose.yml`이 있다면:

```bash
docker-compose up -d qdrant
```

### 3. 데이터베이스 설정

PostgreSQL 데이터베이스를 설정하고 `DATABASE_URL` 환경 변수를 설정하세요.

마이그레이션 실행 (필요한 경우):

```bash
python migrate_db.py
```

### 4. Qdrant 데이터 수집 (선택)

`biostream_corpus_final.csv` 파일이 있다면 Qdrant에 업로드:

```bash
python tools/qdrant_ingest.py biostream_corpus_final.csv
```

또는 환경 변수로 CSV 경로 지정:

```bash
CORPUS_CSV=path/to/biostream_corpus_final.csv python tools/qdrant_ingest.py
```

### 5. FastAPI 서버 실행

```bash
cd app
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

또는 프로젝트 루트에서:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API 엔드포인트

### 헬스 체크

```bash
curl http://localhost:8000/health
```

### 리포트 생성 (공식 엔드포인트)

JWT 인증이 필요합니다:

```bash
# JWT 토큰을 발급받은 후 사용
TOKEN="your_jwt_token_here"
LIFESTYLE_ID=1

curl -X POST "http://localhost:8000/api/generate-report/${LIFESTYLE_ID}?force=false" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json"
```

**파라미터:**
- `lifestyle_id` (경로 파라미터): 리포트를 생성할 Lifestyle 레코드 ID
- `force` (쿼리 파라미터, 선택): `true`일 경우 기존 리포트가 있어도 강제로 재생성 (기본값: `false`)

**응답 예시:**
```json
{
  "success": true,
  "message": "건강 리포트가 성공적으로 생성되었습니다.",
  "report": {
    "sections": {...},
    "citations": [...],
    "survey_summary": {...}
  },
  "lifestyle_id": 1,
  "user_id": 123,
  "generated_at": "2024-01-17T12:00:00"
}
```

### 생성된 리포트 조회

```bash
curl -X GET "http://localhost:8000/api/report/${LIFESTYLE_ID}" \
  -H "Authorization: Bearer ${TOKEN}"
```

## 프로젝트 구조

```
backend/
├── app/
│   ├── api/
│   │   ├── report.py           # 리포트 생성 API (Qdrant 중심 RAG + LangGraph)
│   │   └── ...
│   ├── main.py                 # FastAPI 앱
│   └── ...
├── tools/
│   ├── schemas.py              # Pydantic 스키마 정의
│   ├── qdrant_search.py        # Qdrant 검색 함수 (2단계 검색 전략)
│   ├── survey_tool.py          # 설문 데이터 조회 (user_id 또는 lifestyle_id 기반)
│   ├── report_store.py         # 리포트 저장
│   └── qdrant_ingest.py        # Qdrant 데이터 수집 스크립트
├── langgraph/
│   └── report_graph.py         # LangGraph 워크플로우 (7개 노드)
└── requirements.txt
```

## LangGraph 워크플로우

1. **LoadSurvey**: 설문 데이터 로드
2. **PlanSections**: 생성할 섹션 계획 (rule-based)
3. **BuildQueries**: 섹션별 검색 쿼리 생성 (template-based, ko+en 혼합)
4. **RetrieveEvidence**: Qdrant에서 근거 검색 (섹션별)
5. **WriteSectionDraft**: 섹션별 초안 작성 (LLM)
6. **AssembleReport**: 최종 리포트 조립 (LLM)
7. **SaveReport**: 리포트 저장

## 테스트

### Qdrant 검색 도구 자체 테스트

```bash
cd backend
python tools/qdrant_search.py
```

### 리포트 생성 API 테스트

1. **인증 토큰 발급** (로그인 API 사용)
2. **리포트 생성 요청:**

```bash
# 환경 변수 설정
export TOKEN="your_jwt_token"
export LIFESTYLE_ID=1
export API_URL="http://localhost:8000"

# 리포트 생성
curl -X POST "${API_URL}/api/generate-report/${LIFESTYLE_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -v

# 리포트 조회
curl -X GET "${API_URL}/api/report/${LIFESTYLE_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json"
```

### 호출 흐름

1. **요청**: `POST /api/generate-report/{lifestyle_id}` (JWT 인증)
2. **인증**: JWT 토큰 검증 및 사용자 확인
3. **설문 로드**: `lifestyle_id`로 해당 설문 데이터 조회
4. **LangGraph 워크플로우 실행**:
   - LoadSurvey: 설문 데이터 로드
   - PlanSections: 생성할 섹션 계획
   - BuildQueries: 섹션별 검색 쿼리 생성
   - RetrieveEvidence: Qdrant에서 근거 검색 (2단계 검색 전략)
   - WriteSectionDraft: 섹션별 초안 작성 (LLM)
   - AssembleReport: 최종 리포트 조립 (LLM)
   - SaveReport: 리포트 저장
5. **응답**: 생성된 리포트 JSON 반환

## 주의사항

- Android 앱은 HTTP로 리포트를 요청하고 JSON을 받습니다.
- 모든 파이썬 코드는 서버 백엔드에 존재합니다.
- 토픽은 `list[str]`로 저장/필터합니다.
- `section_norm`은 payload에 필수로 저장됩니다.
