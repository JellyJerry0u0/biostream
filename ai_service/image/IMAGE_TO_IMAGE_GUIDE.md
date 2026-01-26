# Image-to-Image 노화 예측 가이드

## 🎯 핵심 변경사항

### ✅ 수정됨: Image-to-Image 방식
- **이전**: 텍스트 프롬프트만으로 처음부터 얼굴 생성 (❌ 잘못된 방식)
- **현재**: **사용자 얼굴 사진 + 노화 프롬프트** → 노화된 얼굴 생성 (✅ 올바른 방식)

## 📋 필수 요구사항

### 1. 사용자 입력
- **기존 얼굴 사진** (JPG, PNG 등)
- 생활습관 설문 데이터
- 목표 연령 (몇 년 후)

### 2. 환경 설정
```bash
# .env 파일에 추가
GOOGLE_API_KEY=your-api-key
GOOGLE_CLOUD_PROJECT=your-project-id  # Vertex AI 필요
```

### 3. 의존성 설치
```bash
pip install google-cloud-aiplatform
```

## 🎨 지원 모델

### Imagen 4.0 계열 (추천)
- `imagen-4.0-generate-001` - 최신 버전, 균형잡힌 품질
- `imagen-4.0-fast-generate-001` - 빠른 생성 속도
- `imagen-4.0-ultra-generate-001` - 최고 품질

### Imagen 3.0 계열
- `imagen-3.0-generate-002` - 안정적
- `imagen-3.0-generate-001` - 기본 버전
- `imagen-3.0-fast-generate-001` - 빠른 버전

### Gemini Image 계열 (실험적)
- `gemini-2.5-flash-image` - Nano Banana (빠름)
- `gemini-3-pro-image-preview` - Nano Banana Pro (고품질)

> ⚠️ **주의**: Gemini Image 모델은 현재 이미지 편집을 지원하지 않습니다. Imagen 계열 사용을 권장합니다.

## 💻 사용 예시

### Python API

```python
from aging_image_generator import generate_aging_image_prompt_pipeline, UserLifestyleData

# 1. 사용자 데이터 준비
user = UserLifestyleData(
    user_id=1,
    age=35,
    gender="male",
    target_years=10,  # 10년 후 모습
    smoking_status="current",
    uv_exposure_10to16=">2h",
    # ... 기타 설문 데이터
)

# 2. 노화 예측 이미지 생성
result = generate_aging_image_prompt_pipeline(
    user_data=user,
    base_image_path="user_face.jpg",  # 사용자 얼굴 사진 (필수!)
    generate_image=True,
    output_image_path="aged_face_result.png",
    model_name="imagen-4.0-generate-001"  # 모델 선택
)

# 3. 결과 확인
print(f"생성된 이미지: {result['image_path']}")
print(f"리포트: {result['report']}")
print(f"사용된 모델: {result['model_used']}")
```

### FastAPI 엔드포인트 예시

```python
from fastapi import FastAPI, UploadFile, File
from aging_image_generator import generate_aging_image_prompt_pipeline
import shutil

app = FastAPI()

@app.post("/api/v1/aging/generate-image")
async def generate_aging_image(
    lifestyle_id: int,
    face_photo: UploadFile = File(...),
    model_name: str = "imagen-4.0-generate-001"
):
    # 1. 업로드된 얼굴 사진 저장
    temp_face_path = f"uploads/face_{lifestyle_id}.jpg"
    with open(temp_face_path, "wb") as buffer:
        shutil.copyfileobj(face_photo.file, buffer)
    
    # 2. DB에서 생활습관 데이터 로드
    user_data = get_lifestyle_data(lifestyle_id)  # DB 조회 함수
    
    # 3. 노화 예측 파이프라인 실행
    result = generate_aging_image_prompt_pipeline(
        user_data=user_data,
        base_image_path=temp_face_path,
        generate_image=True,
        output_image_path=f"results/aged_{lifestyle_id}.png",
        model_name=model_name
    )
    
    return {
        "aged_image_url": f"/static/results/aged_{lifestyle_id}.png",
        "report": result['report'],
        "visual_description": result['visual_description'],
        "evidence_count": result['evidence_count']
    }
```

## 🔍 작동 방식

```
[사용자 얼굴 사진] ──┐
                    ├──> [Image-to-Image 변환] ──> [노화된 얼굴]
[노화 프롬프트] ────┘
```

### 단계별 처리

1. **Step 1-2**: RAG 검색으로 관련 의학 논문 수집
2. **Step 3**: 논문 근거 기반 노화 영향 분석 + 부위별 상세 묘사
3. **Step 4**: Imagen 최적화 영문 프롬프트 생성
4. **Step 5**: **Image Editing API**로 사용자 얼굴에 노화 효과 적용
   - 입력: 원본 얼굴 사진 + 노화 프롬프트
   - 처리: Imagen의 `edit_image()` 함수 사용
   - 출력: 노화된 얼굴 이미지

## ⚠️ 주의사항

### 1. 기존 얼굴 사진 필수
```python
# ❌ 잘못된 사용 (프롬프트만 생성)
result = generate_aging_image_prompt_pipeline(
    user_data=user,
    base_image_path=None,  # 사진 없음
    generate_image=True
)

# ✅ 올바른 사용 (실제 얼굴 사진 제공)
result = generate_aging_image_prompt_pipeline(
    user_data=user,
    base_image_path="uploads/user_face.jpg",  # 실제 사진
    generate_image=True
)
```

### 2. Vertex AI 프로젝트 설정
- Google Cloud Console에서 프로젝트 생성
- Vertex AI API 활성화
- `.env`에 `GOOGLE_CLOUD_PROJECT` 추가

### 3. 이미지 품질
- **권장 해상도**: 512x512 이상
- **파일 형식**: JPG, PNG
- **얼굴 조건**: 정면, 명확한 조명, 단독 인물

## 🧪 테스트 방법

### 1. 샘플 이미지 준비
```bash
# ai_service 디렉토리에 샘플 얼굴 사진 추가
cp /path/to/face.jpg ai_service/sample_face.jpg
```

### 2. 테스트 실행
```bash
cd ai_service
python aging_image_generator.py
```

### 3. 결과 확인
```bash
# 생성된 파일들
output_aging_prediction.png  # 노화된 얼굴 이미지
```

## 🔧 문제 해결

### 문제: "GOOGLE_CLOUD_PROJECT 환경변수가 설정되지 않았습니다"
**해결**: `.env` 파일에 프로젝트 ID 추가
```bash
GOOGLE_CLOUD_PROJECT=your-project-id
```

### 문제: "Vertex AI SDK가 설치되지 않았습니다"
**해결**: 
```bash
pip install google-cloud-aiplatform
```

### 문제: "기본 사진이 제공되지 않았습니다"
**해결**: `base_image_path` 파라미터에 실제 얼굴 사진 경로 전달
```python
result = generate_aging_image_prompt_pipeline(
    user_data=user,
    base_image_path="path/to/user_face.jpg"  # 필수!
)
```

### 문제: "Gemini Image 모델 사용 실패"
**해결**: Imagen 4.0 계열로 변경
```python
model_name="imagen-4.0-generate-001"  # Gemini 대신 Imagen 사용
```

## 📊 모델 비교

| 모델 | 속도 | 품질 | 용도 |
|------|------|------|------|
| imagen-4.0-ultra | ⭐⭐ | ⭐⭐⭐⭐⭐ | 최고 품질 필요 시 |
| imagen-4.0-generate | ⭐⭐⭐ | ⭐⭐⭐⭐ | 일반 사용 (추천) |
| imagen-4.0-fast | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 빠른 프로토타입 |
| imagen-3.0 | ⭐⭐⭐ | ⭐⭐⭐ | 안정적 버전 |

## 🎯 다음 단계

1. **모바일 앱 연동**:
   - 사용자 얼굴 사진 업로드 기능
   - 실시간 미리보기
   - Before/After 비교 UI

2. **다중 모델 테스트**:
   ```python
   models = [
       "imagen-4.0-generate-001",
       "imagen-4.0-fast-generate-001",
       "imagen-4.0-ultra-generate-001"
   ]
   
   for model in models:
       result = generate_aging_image_prompt_pipeline(
           user_data=user,
           base_image_path="face.jpg",
           model_name=model
       )
       # 품질 비교
   ```

3. **A/B 테스트**:
   - 사용자 만족도 측정
   - 각 모델별 정확도 비교
   - 생성 속도 vs 품질 trade-off 분석

## 📝 라이선스 & 비용

- Vertex AI Imagen: 사용량 기반 과금
- 가격: https://cloud.google.com/vertex-ai/generative-ai/pricing
- 무료 할당량: 프로젝트당 월별 제한

## 💬 지원

문제 발생 시:
1. 로그 확인 (`logger.info` 메시지)
2. Vertex AI Console에서 에러 확인
3. 이슈 트래커에 리포트
