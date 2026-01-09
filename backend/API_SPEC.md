# BioStream Backend API Spec
이 문서는 앱이 서버와 어떻게 "말"하는지 정리한 것임.

## 기본 정보
- 서버 시작점: `backend/main.py` (FastAPI)
- 주요 URL 접두사: `/auth`, `/data`

## 엔드포인트

1) POST /auth/register
- 기능: 새 사용자 등록(간단한 예시)
- 요청 바디(JSON): `{ "email": "user@example.com", "password": "pwd", "nickname": "nick" }`
- 응답 예시: `{ "message": "registered (placeholder)", "email": "user@example.com" }`

2) POST /auth/login
- 기능: 로그인(플레이스홀더 토큰 반환)
- 요청 바디(JSON): `{ "email": "user@example.com", "password": "pwd" }`
- 응답 예시: `{ "access_token": "fake-token", "token_type": "bearer" }`

3) POST /data/upload
- 기능: 사진 업로드(멀티파트 폼)
- 폼 필드: `user_id`(선택) + `file`(업로드할 이미지 파일)
- 예시 cURL:
  ```bash
  curl -X POST "http://localhost:8000/data/upload" \
    -F "user_id=1" \
    -F "file=@/path/to/photo.jpg"
  ```
- 응답 예시: `{ "filename": "photo.jpg", "saved_path": "backend/uploads/20260109_...jpg" }`

4) POST /data/survey
- 기능: 설문/메타데이터 제출(간단한 폼)
- 폼 필드 예시: `user_id`, `target_years`, 기타 설문 항목들
- 응답 예시: `{ "status": "received", "user_id": 1 }`

5) (추후) GET /data/result/{id}
- 기능: 분석 결과 조회 (플레이스홀더)

## 동작 흐름 (간단)
- 사용자가 앱에서 사진을 고르면 프론트엔드가 `/data/upload`로 보냄
- 서버는 파일을 `backend/uploads/` 폴더에 저장하고 DB에 레코드를 남김(다음 단계)
- AI 분석을 호출하여 `generated_image_url` 등 결과를 채우고 클라이언트에 전달함

## 개발/테스트 팁
- 로컬에서 서버 실행:
  ```bash
  uvicorn backend.main:app --reload
  ```
- FastAPI에는 Swagger UI가 있음: `http://localhost:8000/docs`
- 먼저 업로드가 잘 되는지 확인한 뒤 AI 연결을 테스트하세요.

---
파일은 프로젝트 루트의 `backend/API_SPEC.md`에 저장되어 있습니다.
