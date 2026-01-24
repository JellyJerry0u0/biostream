# 노화 이미지 생성 파이프라인 사용 가이드 (고도화 버전)

## 개요

이 파이프라인은 사용자의 설문 데이터와 Qdrant에서 검색된 의학 논문을 결합하여, **10년 후의 노화된 얼굴 이미지를 생성하기 위한 프롬프트**를 자동으로 생성합니다.

### 🎯 핵심 고도화 기능

1. **Step 3: 노화 영향 평가 및 시각적 묘사 생성**
   - RAG를 통해 사용자 생활습관과 관련된 의학 논문 검색
   - LLM이 논문의 정량적 수치(Odds Ratio, p-value 등)와 사용자 데이터를 결합
   - 노화 영향 분석 리포트 및 구체적인 시각적 묘사 생성

2. **Step 4: 이미지 생성용 프롬프트 정제**
   - 한글 시각적 묘사를 Imagen 모델에 적합한 영문 프롬프트로 변환
   - 의학적 용어와 구체적인 디테일 포함

---

## 설치 및 설정

### 1. 필요한 라이브러리 설치

```bash
cd ai_service
pip install -r requirements.txt
```

`requirements.txt`에 다음이 포함되어 있어야 합니다:
```
langchain-google-genai
python-dotenv
qdrant-client
pandas
openpyxl
```

### 2. 환경 변수 설정

`.env` 파일에 다음을 추가:

```env
GOOGLE_API_KEY=your_google_api_key_here
QDRANT_URL=http://localhost:6333
COLLECTION_NAME=biostream_v1
```

---

## 사용 방법

### 기본 사용 예시

```python
from ai_service.aging_image_generator import (
    generate_aging_image_prompt_pipeline,
    UserLifestyleData
)

# 1. 사용자 데이터 준비 (backend의 Lifestyle 모델과 동일한 구조)
user_data = UserLifestyleData(
    user_id=123,
    age=35,  # 현재 나이
    gender="male",
    outcomes=["wrinkle", "pigmentation"],
    target_years=10,  # 10년 후 예측
    
    # 생활습관 데이터
    sleep_hours_weekday=5.5,
    sleep_hours_weekend=7.0,
    sleep_quality_score=6.0,
    
    uv_exposure_10to16=">2h",
    sunscreen_frequency="sometimes",
    
    smoking_status="current",
    smoking_amount_per_day="반갑",
    
    drinking_days_per_week="2-3",
    drinking_amount_per_session="소주 반병",
    
    stress_score=8.0,
    caffeine_intake="3+",
    
    aerobic_weekly="0",
    resistance_weekly="0",
    
    height=175.0,
    weight=75.0,
    
    skin_type="combination",
    skin_concerns=["wrinkle", "pigmentation", "dryness"],
    skin_satisfaction=5.0
)

# 2. 파이프라인 실행
result = generate_aging_image_prompt_pipeline(user_data)

# 3. 결과 활용
print("노화 영향 분석 리포트:")
print(result['report'])

print("\n부위별 시각적 묘사 (한글):")
print(result['visual_description'])

print("\nImagen 3 최적화 프롬프트 (영문):")
print(result['imagen_prompt'])

print(f"\n시각적 영향 강도 점수:")
print(result['impact_scores'])

print(f"\n검색된 논문 수: {result['evidence_count']}개")
print(f"사용된 검색 쿼리: {result['queries_used']}")
```

### 결과 구조

```python
{
    'report': str,  # 노화 영향 분석 리포트 (한글, 논문 수치 포함)
    'visual_description': str,  # 부위별 상세 시각적 묘사 (한글)
    'imagen_prompt': str,  # Imagen 3용 최적화 영문 프롬프트
    'impact_scores': str,  # 시각적 영향 강도 점수 요약 (0~10점)
    'evidence_count': int,  # 검색된 논문 수
    'queries_used': List[str],  # 사용된 검색 쿼리 리스트
    'full_llm_response': str  # Gemini의 전체 응답
}
```

---

## 고도화 기능 상세 설명

### 1. 논문 수치 → 시각적 강도 변환 로직

```python
from ai_service.aging_image_generator import VisualImpactScore

# 논문에서 추출된 수치
impact = VisualImpactScore(
    factor_name="흡연",
    odds_ratio=3.21,  # OR=3.21
    p_value=0.001,    # p<0.001
    effect_description="주름 발생 증가"
)

# 시각적 강도 점수 계산 (0~10)
intensity = impact.calculate_visual_intensity()  # 7.8점
descriptor = impact.get_intensity_descriptor()   # "심한"

# 변환 규칙:
# OR < 1.0  → 보호 효과, 점수 낮음
# OR 1.0~2.0 → 경미한 영향, 점수 2~4
# OR 2.0~3.0 → 중등도 영향, 점수 4~6
# OR 3.0 이상 → 강한 영향, 점수 6~10
# p-value가 낮을수록 가중치 증가 (×1.1 ~ ×1.3)
```

### 2. Imagen 3 프롬프트 최적화 규칙

**✅ 필수 포함 키워드:**
- `Hyper-realistic macro photography`
- `8k resolution` / `Ultra-high definition`
- `Medical-grade detail`
- `Cinematic lighting` / `Soft diffused light`
- `Front-facing portrait`

**✅ 의학적 용어 사용 (추상적 단어 금지):**
- ❌ "old face" → ✅ "facial features with advanced photoaging"
- ❌ "wrinkles" → ✅ "deep periorbital wrinkles", "prominent nasolabial folds"
- ❌ "dark skin" → ✅ "increased melanin deposition", "hyperpigmentation"
- ❌ "saggy" → ✅ "loss of skin elasticity", "ptosis"

**예시 프롬프트:**
```
Hyper-realistic macro photography of a 45-year-old male Asian person with deep periorbital wrinkles (crow's feet extending 3cm laterally), prominent nasolabial folds (depth 2mm), facial hyperpigmentation with melasma patches on bilateral cheeks, loss of skin elasticity in periorbital region, darker Fitzpatrick phototype with 15% increased melanin deposition, medical-grade detail, 8k resolution, cinematic lighting, front-facing portrait, photorealistic, professional photography, ultra-high definition, soft diffused light, neutral expression
```

---

## Backend API 연동 (업데이트)

### 1. Backend에서 Lifestyle 데이터 가져오기

```python
# backend/app/api/aging_prediction.py (예시)

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Dict
from datetime import datetime

from ..database import get_db
from ..models import User, Lifestyle
from ..auth.dependencies import get_current_user

# ai_service import
import sys
sys.path.append('../ai_service')
from aging_image_generator import (
    generate_aging_image_prompt_pipeline,
    UserLifestyleData
)

router = APIRouter()


@router.post("/aging/generate-prompt/{lifestyle_id}")
async def generate_aging_prompt(
    lifestyle_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
) -> Dict:
    """
    사용자의 설문 데이터를 기반으로 노화 이미지 생성 프롬프트를 생성합니다.
    """
    # 1. Lifestyle 데이터 조회
    lifestyle = db.query(Lifestyle).filter(
        Lifestyle.id == lifestyle_id,
        Lifestyle.user_id == current_user.id
    ).first()
    
    if not lifestyle:
        raise HTTPException(status_code=404, detail="설문 데이터를 찾을 수 없습니다.")
    
    # 2. 나이 계산 (생년월일로부터)
    current_age = calculate_age(current_user.birthdate)
    
    # 3. UserLifestyleData 변환
    user_data = UserLifestyleData(
        user_id=current_user.id,
        age=current_age,
        gender=current_user.gender,
        is_pregnant=current_user.is_pregnant,
        
        outcomes=lifestyle.outcomes or [],
        target_years=lifestyle.target_years or 10,
        
        sleep_hours_weekday=lifestyle.sleep_hours_weekday,
        sleep_hours_weekend=lifestyle.sleep_hours_weekend,
        sleep_quality_score=lifestyle.sleep_quality_score,
        
        uv_exposure_10to16=lifestyle.uv_exposure_10to16,
        sunscreen_frequency=lifestyle.sunscreen_frequency,
        sunscreen_reapply=lifestyle.sunscreen_reapply,
        outdoor_sports_uv=lifestyle.outdoor_sports_uv,
        
        drinking_days_per_week=lifestyle.drinking_days_per_week,
        drinking_amount_per_session=lifestyle.drinking_amount_per_session,
        smoking_status=lifestyle.smoking_status,
        smoking_amount_per_day=lifestyle.smoking_amount_per_day,
        
        stress_score=lifestyle.stress_score,
        caffeine_intake=lifestyle.caffeine_intake,
        caffeine_timing=lifestyle.caffeine_timing,
        
        aerobic_weekly=lifestyle.aerobic_weekly,
        resistance_weekly=lifestyle.resistance_weekly,
        height=lifestyle.height,
        weight=lifestyle.weight,
        
        skin_type=lifestyle.skin_type,
        skin_concerns=lifestyle.skin_concerns or [],
        skin_satisfaction=lifestyle.skin_satisfaction
    )
    
    # 4. 파이프라인 실행
    try:
        result = generate_aging_image_prompt_pipeline(user_data)
        
        # 5. 결과 반환
        return {
            "lifestyle_id": lifestyle_id,
            "user_id": current_user.id,
            "target_age": current_age + user_data.target_years,
            "report": result['report'],
            "visual_description": result['visual_description'],
            "imagen_prompt": result['imagen_prompt'],
            "evidence_count": result['evidence_count'],
            "queries_used": result['queries_used']
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=500, 
            detail=f"프롬프트 생성 실패: {str(e)}"
        )


def calculate_age(birthdate) -> int:
    """생년월일로부터 현재 나이 계산"""
    if not birthdate:
        return 30  # 기본값
    
    today = datetime.now().date()
    age = today.year - birthdate.year
    
    if (today.month, today.day) < (birthdate.month, birthdate.day):
        age -= 1
    
    return age
```

### 2. API 엔드포인트 등록

```python
# backend/app/main.py

from fastapi import FastAPI
from .api import aging_prediction  # 위에서 만든 라우터

app = FastAPI()

# 라우터 등록
app.include_router(
    aging_prediction.router,
    prefix="/api/v1",
    tags=["aging"]
)
```

### 3. API 호출 예시

```bash
# 프롬프트 생성
curl -X POST "http://localhost:8000/api/v1/aging/generate-prompt/123" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

응답:
```json
{
  "lifestyle_id": 123,
  "user_id": 456,
  "target_age": 45,
  "report": "## 1. 노화 영향 분석 리포트\n\n...",
  "visual_description": "## 2. 시각적 묘사\n\n- **눈가 주변**: ...",
  "imagen_prompt": "A 45-year-old Asian male with deep periorbital wrinkles...",
  "evidence_count": 12,
  "queries_used": ["흡연 피부 노화", "자외선 광노화", ...]
}
```

---

## 고급 사용법

### 1. 개별 단계 실행

```python
from ai_service.aging_image_generator import AgingImageGenerator

# 초기화
generator = AgingImageGenerator()

# Step 1: 검색 쿼리 생성
queries = generator.generate_search_queries(user_data)
print(f"검색 쿼리: {queries}")

# Step 2: RAG 검색
evidence = generator.search_evidence(queries)
print(f"검색된 논문: {len(evidence)}개")

# Step 3: 리포트 및 시각적 묘사 생성
step3_result = generator.generate_aging_report_and_visual_description(
    user_data, evidence
)
print(f"리포트: {step3_result['report']}")
print(f"시각적 묘사: {step3_result['visual_description']}")

# Step 4: Imagen 프롬프트 정제
imagen_prompt = generator.refine_visual_description_to_imagen_prompt(
    user_data, step3_result['visual_description']
)
print(f"Imagen 프롬프트: {imagen_prompt}")
```

### 2. 커스텀 LLM 설정

```python
from langchain_google_genai import ChatGoogleGenerativeAI

# 커스텀 LLM 초기화
custom_llm = ChatGoogleGenerativeAI(
    model="gemini-1.5-pro",
    google_api_key="your_key",
    temperature=0.1,  # 더 일관된 결과
    max_tokens=4096
)

# AgingImageGenerator에 전달
generator = AgingImageGenerator(google_api_key="your_key")
generator.llm = custom_llm
```

---

## 다음 단계: Imagen으로 이미지 생성

생성된 `imagen_prompt`를 Google Imagen API에 전달하여 실제 이미지를 생성할 수 있습니다:

```python
from google.cloud import aiplatform
from vertexai.preview.vision_models import ImageGenerationModel

# Imagen 초기화
model = ImageGenerationModel.from_pretrained("imagegeneration@005")

# 이미지 생성
images = model.generate_images(
    prompt=result['imagen_prompt'],
    number_of_images=1,
    aspect_ratio="1:1",
    safety_filter_level="block_some",
    person_generation="allow_adult"
)

# 이미지 저장
images[0].save(location="aged_face.png")
```

---

## 문제 해결

### 1. GOOGLE_API_KEY 오류
```
ValueError: GOOGLE_API_KEY가 설정되지 않았습니다.
```
→ `.env` 파일에 `GOOGLE_API_KEY=your_key` 추가

### 2. Qdrant 연결 오류
```
QdrantException: Could not connect to Qdrant
```
→ Qdrant가 실행 중인지 확인: `docker ps | grep qdrant`

### 3. 검색 결과 없음
```
evidence_count: 0
```
→ Qdrant에 데이터가 적재되었는지 확인: `python ai_service/main.py`

### 4. LLM 응답 파싱 실패
```
시각적 묘사를 추출할 수 없습니다.
```
→ LLM이 "## 2. 시각적 묘사" 헤더를 사용하지 않음. `_parse_llm_response()` 메서드의 마커 리스트를 확인

---

## 성능 최적화

1. **RAG 검색 최적화**
   - `max_results_per_query` 조정 (기본 3)
   - 검색 쿼리 수 제한 (기본 10)

2. **LLM 호출 최적화**
   - `temperature` 낮추기 (더 일관된 결과)
   - 프롬프트 길이 최적화

3. **캐싱**
   - 동일한 사용자 데이터에 대한 결과 캐싱
   - RAG 검색 결과 캐싱

---

## 라이선스

이 코드는 BioStream 프로젝트의 일부입니다.
