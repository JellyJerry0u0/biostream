# Vertex AI Imagen 3 설정 가이드

BioStream에서 Google Cloud Vertex AI Imagen 3를 사용하여 노화 이미지를 생성하는 방법입니다.

## 1. GCP 프로젝트 설정

### 1-1. 프로젝트 생성
1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. 프로젝트 ID 복사 (예: `biostream-project-123456`)

### 1-2. Vertex AI API 활성화
```bash
# GCP Console에서 또는 gcloud CLI로
gcloud services enable aiplatform.googleapis.com --project=YOUR_PROJECT_ID
```

또는 웹에서:
- https://console.cloud.google.com/apis/library/aiplatform.googleapis.com
- "사용 설정" 클릭

### 1-3. 결제 계정 연결
⚠️ **중요**: Imagen 3는 유료 API입니다
- 가격: 이미지당 약 $0.02~$0.04
- GCP 결제 계정 연결 필요
- https://console.cloud.google.com/billing

## 2. 인증 설정

### 방법 A: gcloud CLI 사용 (권장)

```powershell
# 1. gcloud CLI 설치 (아직 없다면)
# https://cloud.google.com/sdk/docs/install

# 2. 인증
gcloud auth application-default login

# 3. 프로젝트 설정
gcloud config set project YOUR_PROJECT_ID
```

### 방법 B: 서비스 계정 키 사용

1. **서비스 계정 생성**
   - https://console.cloud.google.com/iam-admin/serviceaccounts
   - "서비스 계정 만들기" 클릭
   - 역할: `Vertex AI User` 부여

2. **JSON 키 다운로드**
   - 생성된 서비스 계정 → "키" 탭
   - "키 추가" → "새 키 만들기" → JSON 선택
   - 파일 다운로드 (예: `biostream-service-account.json`)

3. **.env 파일에 추가**
   ```env
   GOOGLE_APPLICATION_CREDENTIALS=C:/path/to/biostream-service-account.json
   ```

## 3. .env 파일 설정

```env
# Vertex AI Imagen 3 설정
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=us-central1

# 서비스 계정 키 경로 (방법 B 사용 시)
# GOOGLE_APPLICATION_CREDENTIALS=C:/path/to/service-account-key.json
```

**리전 선택 가이드:**
- `us-central1`: 미국 중부 (권장, 가장 안정적)
- `us-east1`: 미국 동부
- `europe-west4`: 유럽
- `asia-northeast1`: 도쿄
- `asia-northeast3`: 서울 (한국)

## 4. 테스트

```powershell
# BioStream 가상환경 활성화
cd C:\Users\82102\BioStream
.venv\Scripts\Activate.ps1

# 테스트 실행
cd ai_service\image
python test_image_pipeline.py

# 옵션 3 또는 4 선택
# 3: Gemini 3.0 Pro (Imagen 3)
# 4: Gemini 2.5 Flash (Imagen 3 Fast)
```

## 5. 문제 해결

### 오류: "credentials not found"
```powershell
# gcloud 재인증
gcloud auth application-default login
```

### 오류: "Permission denied"
- 서비스 계정에 `Vertex AI User` 역할이 있는지 확인
- IAM 페이지: https://console.cloud.google.com/iam-admin/iam

### 오류: "Quota exceeded"
- Vertex AI 할당량 페이지: https://console.cloud.google.com/iam-admin/quotas
- Imagen API 할당량 증가 요청

### 오류: "Billing not enabled"
- 결제 계정 연결: https://console.cloud.google.com/billing
- 프로젝트에 결제 계정 연결 확인

## 6. Imagen 3 vs 다른 모델 비교

| 모델 | 장점 | 단점 | 비용 |
|------|------|------|------|
| **Replicate SDXL** | 고품질, 안정적 | 느림 | $0.01/이미지 |
| **OpenAI gpt-image-1** | 빠름, Identity 보존 우수 | 가끔 실패 | $0.02/이미지 |
| **Imagen 3** | Google 기술, 높은 품질 | 설정 복잡, 비쌈 | $0.02~$0.04/이미지 |

## 7. 프로덕션 배포 시 고려사항

### A. 비용 최적화
```python
# 캐싱 전략
# - 동일한 사용자 프로필은 24시간 캐시
# - 생성된 이미지를 S3/Cloud Storage에 저장
# - CDN 사용으로 재요청 방지
```

### B. 할당량 관리
- Vertex AI 할당량 모니터링
- 피크 시간대 rate limiting 구현
- 대기열 시스템 (Redis/Celery)

### C. 백업 전략
```python
# 순차 폴백 (fallback) 로직
1. Imagen 3 시도
2. 실패 시 → OpenAI gpt-image-1
3. 실패 시 → Replicate SDXL
```

## 8. API 문서 참고

- Vertex AI Imagen API: https://cloud.google.com/vertex-ai/docs/generative-ai/image/overview
- Python SDK: https://cloud.google.com/python/docs/reference/aiplatform/latest
- 가격 정보: https://cloud.google.com/vertex-ai/pricing

## 9. 다음 단계

1. ✅ .env 파일에 GCP 프로젝트 ID 추가
2. ✅ gcloud 인증 완료
3. ✅ 결제 계정 연결
4. ✅ `python test_image_pipeline.py` 실행
5. ✅ 옵션 3 또는 4 선택하여 테스트
6. ✅ 생성된 이미지 품질 확인
7. ✅ 다른 모델(Replicate, OpenAI)과 비교
