# BioStream Monorepo

BioStream는 모바일 앱(Flutter), 백엔드(FastAPI), Firebase Functions, 부가 실험 폴더를 함께 관리하는 모노레포입니다.

## Start Here (처음 실행)

아래 3가지 시나리오 중 하나를 먼저 선택하세요.

- **A. 모바일 UI만 빠르게 확인**
  1. `cd biostream`
  2. `flutter pub get`
  3. `flutter run`
- **B. 모바일 + 백엔드 로컬 연결**
  1. 백엔드: `cd backend && pip install -r requirements.txt && alembic upgrade head && uvicorn app.main:app --reload --host 0.0.0.0 --port 8080`
  2. 모바일: `cd biostream && flutter run`
- **C. 로컬 통합 스택(Docker)**
  1. 루트에서 `docker compose up --build`
  2. API는 `http://localhost:8080`으로 노출

> 중요: Flutter 앱의 작업 디렉터리는 루트가 아니라 **`biostream/`** 입니다.
> 루트의 Flutter 관련 잔존 파일(`pubspec.yaml`, `android/`, `ios/` 등)은 실행 기준이 아닙니다.

## 폴더 역할

- `biostream/`  
  Flutter 앱 소스 (`lib/`, `android/`, `ios/`, `test/`)
- `backend/`  
  FastAPI + SQLAlchemy + 리포트 파이프라인 + MCP 연계 코드
- `functions/`  
  Firebase Cloud Functions (TypeScript)
- `dataconnect/`  
  Data Connect 관련 스키마/예시 쿼리(실험/보조 성격)
- `docker-compose.yml`  
  DB(Postgres) + API + MCP + Qdrant 로컬 통합 실행

## 빠른 시작 (명령어)

### 1) 앱 실행 (Flutter)

```bash
cd biostream
flutter pub get
flutter run
```

### 2) 백엔드 실행 (로컬)

```bash
cd backend
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
```

### 3) 전체 스택 실행 (Docker)

```bash
docker compose up --build
```

API 외부 포트는 `8080`으로 노출됩니다.

## 운영 기준 경로 (중요)

- FastAPI 앱 엔트리포인트: `backend/app/main.py` (`app.main:app`)
- DB/ORM 단일 소스: `backend/app/database.py`, `backend/app/models.py`
- API 라우터 기준 경로: `backend/app/api/*`

레거시 `backend/main.py`, `backend/database.py`, `backend/models.py`는 제거되었습니다.
레거시 `backend/api/*`, `backend/app/api/lifestyle.py`도 제거되어 더 이상 사용되지 않습니다.

## 실행 위치 규칙 (헷갈리기 쉬운 포인트)

- Flutter 관련 명령(`flutter run`, `flutter test`, `dart analyze`)은 `biostream/`에서 실행
- Backend 관련 명령(`uvicorn app.main:app`, `python3 -m compileall app`)은 `backend/`에서 실행
- Docker 관련 명령(`docker compose ...`)은 루트에서 실행

## 선택 컴포넌트 안내

- `functions/`: Firebase Cloud Functions 개발 시에만 필요
- `dataconnect/`: Data Connect 실험/보조 목적, 앱 기본 실행에는 필수 아님

## DB 마이그레이션 규칙

- Postgres 스키마 변경은 `backend/alembic`으로만 관리
- 로컬/도커 실행 전 `alembic upgrade head` 선적용
- Qdrant 임베딩은 별도 볼륨(`qdrant_data`)에 저장되며, Postgres 마이그레이션과 독립적
- 상세 템플릿/체크리스트는 `backend/README.md`의 Alembic 섹션 참고

## 환경변수 파일

- Docker 실행용: 루트 `.env` (예시: `.env.example`)
- 백엔드 로컬 실행용: `backend/.env` (예시: `backend/.env.example`)

## 문서

- 백엔드 상세: `backend/README.md`
- Flutter 리팩토링 규칙: `biostream/REFACTORING_GUIDE.md`
- Flutter 구조 맵: `biostream/FLUTTER_STRUCTURE_MAP.md`

## 로컬 시크릿 (`--dart-define-from-file`)

API 키는 코드 하드코딩 대신 로컬 비추적 파일로 관리하세요.

```bash
cd biostream
cp dev.secrets.json.example dev.secrets.json
flutter run --dart-define-from-file=dev.secrets.json
```

Windows 환경에서는 `cp` 대신 `copy`를 사용하세요.
