# BioStream Backend

Qdrant 중심 RAG + LangGraph 기반 리포트 오케스트레이션 백엔드

## Start Here

백엔드 실행 목적에 따라 아래 중 하나를 선택하세요.

- **A. API 서버만 로컬에서 빠르게 실행**
  1. `cd backend`
  2. `pip install -r requirements.txt`
  3. `alembic upgrade head`
  4. `uvicorn app.main:app --reload --host 0.0.0.0 --port 8080`
- **B. 의존 서비스까지 포함해 실행**
  1. 루트에서 `docker compose up --build`
  2. API 접근: `http://localhost:8080`

> 기본 개발 기준 엔트리포인트는 `app.main:app` 입니다.

## 아키텍처

- **Qdrant**: 로컬 도커로 실행되는 벡터 DB (기본 URL: http://localhost:6333)
- **LangGraph**: 리포트 생성 워크플로우 오케스트레이션
- **Gemini API**: 임베딩 생성 (gemini-embedding-001, 768차원) 및 LLM 호출
- **FastAPI**: REST API 서버

## 환경 설정

`.env` 파일을 생성하고 다음 환경 변수를 설정하세요:

빠르게 시작하려면:

```bash
cd backend
cp .env.example .env
```

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

# JWT
JWT_SECRET_KEY=replace-with-a-long-random-secret
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

또는 `docker-compose.yml`이 있다면 (`docker compose` 권장):

```bash
docker compose up -d qdrant
```

### 3. 데이터베이스 설정 (Alembic 기준)

PostgreSQL 데이터베이스를 설정하고 `DATABASE_URL` 환경 변수를 설정하세요.

스키마 초기화/변경은 Alembic 마이그레이션으로만 관리합니다.

```bash
cd backend
alembic upgrade head
```

`migrate_db.py`는 과거 수동 보정용 레거시 스크립트이며, 신규 스키마 변경에는 사용하지 마세요.

레거시 API 경로인 `backend/api/*` 및 `backend/app/api/lifestyle.py`는 제거되었습니다.

레거시 스크립트가 꼭 필요한 경우에만:

```bash
python3 migrate_db.py
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

### 5. FastAPI 서버 실행 (권장 엔트리포인트)

프로젝트 루트(`backend`)에서 아래 명령을 사용하세요:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
```

서버 실행 전에 반드시 아래를 1회 실행하세요:

```bash
alembic upgrade head
```

## 실행 위치 규칙

- Python/FastAPI 명령은 `backend/`에서 실행
- Docker 명령은 모노레포 루트에서 실행
- API 라우터 코드는 `backend/app/api/*` 기준

## DB 변경 절차 (팀 룰)

1. 모델 변경
2. `alembic revision --autogenerate -m "..."` 생성
3. 생성된 revision 검토/보정
4. `alembic upgrade head` 적용
5. 앱 실행 및 API 스모크 체크

Qdrant 임베딩 데이터는 Postgres 마이그레이션과 분리되어 있습니다.  
`docker compose down -v`를 실행하지 않는 한 `qdrant_data` 볼륨 데이터는 유지됩니다.

### Alembic 작업 템플릿

```bash
cd backend

# 1) 모델 수정 후 revision 생성
alembic revision --autogenerate -m "add_xxx_to_yyy"

# 2) 생성된 파일 검토 (nullable/default/index/fk 의도 확인)
# backend/alembic/versions/<revision>.py

# 3) 적용
alembic upgrade head

# 4) 롤백 점검(선택)
alembic downgrade -1
alembic upgrade head
```

### Revision 리뷰 체크리스트

- 의도하지 않은 `drop table` / `drop column`이 없는지
- `nullable=False` 컬럼 추가 시 기존 데이터 대응(default/backfill)이 있는지
- 인덱스/유니크/외래키 이름이 명확한지
- `upgrade()`와 `downgrade()`가 대칭적으로 작성되었는지
- 운영 데이터에 영향이 큰 DDL은 배포 전 백업/점검 절차가 있는지

### 커밋 메시지 예시 (DB 변경)

- `backend: add alembic migration for health_data indexes`
- `backend: add lifestyle report fields migration`

## API 엔드포인트

### 헬스 체크

```bash
curl http://localhost:8080/health
```

### Readiness 체크

```bash
curl http://localhost:8080/ready
```

### 리포트 생성 (공식 엔드포인트)

JWT 인증이 필요합니다:

```bash
# JWT 토큰을 발급받은 후 사용
TOKEN="your_jwt_token_here"
LIFESTYLE_ID=1

curl -X POST "http://localhost:8080/api/generate-report/${LIFESTYLE_ID}?force=false" \
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
curl -X GET "http://localhost:8080/api/report/${LIFESTYLE_ID}" \
  -H "Authorization: Bearer ${TOKEN}"
```

### 카카오 로그인 (보안 검증 방식)

카카오 로그인은 클라이언트가 `kakao_id/email`을 임의 전달하지 않고,  
`access_token`만 서버로 전달하면 서버가 카카오 API(`/v2/user/me`)로 직접 검증합니다.

요청 예시:

```bash
curl -X POST "http://localhost:8080/auth/kakao-login" \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "kakao_access_token_here"
  }'
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
├── report_modules/
│   └── report_graph.py         # 리포트 생성 그래프/파이프라인
├── tools/
│   ├── schemas.py              # Pydantic 스키마 정의
│   ├── qdrant_search.py        # Qdrant 검색 함수 (2단계 검색 전략)
│   ├── survey_tool.py          # 설문 데이터 조회 (user_id 또는 lifestyle_id 기반)
│   ├── report_store.py         # 리포트 저장
│   └── qdrant_ingest.py        # Qdrant 데이터 수집 스크립트
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
export API_URL="http://localhost:8080"

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

## Health Sync Key Refactor (activeCaloriesKcal)

`nutritionCaloriesKcal`는 의미가 모호해 Health Connect의 활동 칼로리와 일치하는
`activeCaloriesKcal`로 표준화했습니다.

- API 표준 입력/출력 키: `activeCaloriesKcal`
- 하위 호환 입력 키: `nutritionCaloriesKcal` (서버에서 계속 수용)
- DB 표준 컬럼: `active_calories_kcal`

### DB 마이그레이션

```bash
cd backend
python migrate_db.py
```

마이그레이션 동작:
- `health_data.active_calories_kcal` 컬럼을 없으면 생성
- 기존 `nutrition_calories_kcal` 값이 있으면 `active_calories_kcal`로 이관

### Docker 환경에서 실행

```bash
docker exec biostream_api python /app/migrate_db.py
```

주의:
- 현재 compose는 `./backend/app:/app/app`만 마운트합니다.
- 루트의 `backend/migrate_db.py`를 수정한 경우, 컨테이너 이미지가 오래되었으면
  컨테이너 내부 스크립트와 달라질 수 있습니다.
- 이 경우 `docker compose build backend ; docker compose up -d backend`로
  이미지 재빌드 후 마이그레이션을 실행하세요.

### 팀원 전달 체크리스트

1. 백엔드
- `python migrate_db.py` 실행 후 `health_data.active_calories_kcal` 존재 확인

2. 모바일
- Android: `ActiveCaloriesBurnedRecord` 권한 허용
- iOS: HealthKit `activeEnergyBurned` 권한 허용

3. API 검증
- `GET /api/v1/yesterday-health` 응답에 `activeCaloriesKcal` 필드가 오는지 확인

4. UI 검증
- "오늘의 나" 탭에서 `활동 칼로리` 카드가 `activeCaloriesKcal` 값으로 표시되는지 확인

### 빠른 검증 SQL

```sql
SELECT user_id, sync_date, active_calories_kcal
FROM health_data
ORDER BY sync_date DESC
LIMIT 20;
```
- 토픽은 `list[str]`로 저장/필터합니다.
- `section_norm`은 payload에 필수로 저장됩니다.
