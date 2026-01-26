# BioStream Pipeline 사용 가이드

## 개요
BioStream Pipeline은 RAG(논문 근거) → Gemini 분석 → Replicate SDXL 이미지 생성을 하나의 파이프라인으로 통합한 AI 노화 시뮬레이터입니다.

## 주요 특징
- **3단계 프롬프트 정제 과정 생략**: 다이렉트 연결로 효율성 극대화
- **논문 기반 분석**: Qdrant RAG를 통한 과학적 근거 제공
- **Gemini 1.5 Pro 통합**: 한글 리포트 + 영문 프롬프트 동시 생성
- **SDXL Img2Img**: Identity 보존하며 노화 효과 적용

## 설치

### 1. 필수 패키지 설치
```bash
cd ai_service
pip install -r requirements.txt
```

### 2. 환경 변수 설정
`.env` 파일에 다음 항목들을 설정하세요:

```env
# Google API (Gemini 및 Embedding)
GOOGLE_API_KEY=your_google_api_key_here

# Replicate API
REPLICATE_API_TOKEN=your_replicate_token_here

# Qdrant 설정
QDRANT_URL=http://localhost:6333
COLLECTION_NAME=biostream_v1
```

### 3. Qdrant 데이터 준비
파이프라인 실행 전 Qdrant에 논문 데이터가 적재되어 있어야 합니다:

```bash
python main.py
```

## 사용 방법

### 기본 사용
```python
from biostream_pipeline import BioStreamPipeline

# 사용자 데이터 정의
user_data = {
    'age': 35,
    'gender': '남성',
    'smoking': True,
    'drinking': True,
    'stress_level': 8,
    'sleep_hours': 5,
    'exercise_frequency': 1
}

# 파이프라인 실행
pipeline = BioStreamPipeline()
result = pipeline.run(
    user_data=user_data,
    image_path="path/to/user_photo.jpg"
)

# 결과 사용
print("생성 이미지:", result['image_url'])
print("한글 리포트:", result['korean_report'])
print("논문 근거:", result['evidence'])
```

### 테스트 스크립트 실행
```bash
python test_pipeline.py
```

## 결과 데이터 구조

```python
{
    'image_url': str,          # 생성된 노화 이미지 URL
    'korean_report': str,      # 사용자용 한글 분석 리포트
    'evidence': list,          # 논문 근거 리스트
    'raw_prompt': str          # SDXL에 사용된 원본 영문 프롬프트
}
```

### evidence 구조
```python
[
    {
        'rank': 1,
        'score': 0.8523,
        'text': '논문 내용...',
        'paper_id': 'PMC1234567',
        'evidence_level': '1',
        'study_type': 'RCT'
    },
    ...
]
```

## 파이프라인 단계별 설명

### Step 1: RAG 검색 (search_evidence)
- 사용자 데이터를 기반으로 검색 쿼리 자동 생성
- Qdrant에서 유사도 기반 상위 5개 논문 근거 검색
- 근거 수준(evidence level) 가중치 적용

### Step 2: Gemini 통합 분석 (analyze_with_gemini)
- 논문 근거 + 사용자 데이터를 Gemini 1.5 Pro에 전달
- 출력 1: 한글 분석 리포트 (생활습관 영향, 예상 노화 양상, 권장사항)
- 출력 2: SDXL용 영문 프롬프트 (직설적이고 구체적인 표현 사용)

**중요**: 영문 프롬프트는 RAI 정책 우회용 순화 단어를 사용하지 않음
- ✅ 사용: "deep wrinkles", "skin sagging", "age spots"
- ❌ 미사용: "mature appearance", "time's effect"

### Step 3: SDXL 이미지 생성 (generate_image_with_sdxl)
- Replicate의 SDXL 모델 사용 (Image-to-Image)
- `prompt_strength`: 0.55 (기본값, Identity 유지)
- 원본 얼굴 특징 보존하며 노화 효과만 적용

## 파라미터 조정

### prompt_strength 조정
Identity 보존 정도를 조절할 수 있습니다:

```python
result = pipeline.generate_image_with_sdxl(
    image_path="photo.jpg",
    prompt="...",
    prompt_strength=0.6  # 0.5~0.7 권장
)
```

- **낮은 값 (0.5)**: 원본 얼굴 더 많이 보존, 변화 적음
- **높은 값 (0.7)**: 노화 효과 더 강함, Identity 약간 손실 가능

### RAG 검색 개수 조정
`search_evidence` 메서드에서 `limit` 파라미터 수정:

```python
search_results = self.qdrant_client.query_points(
    collection_name=self.collection_name,
    query=query_vector,
    limit=10,  # 기본값 5 → 10으로 증가
    ...
)
```

## 에러 처리

### 일반적인 오류와 해결책

#### 1. `GOOGLE_API_KEY가 설정되지 않았습니다`
- `.env` 파일에 API 키 추가
- 환경 변수가 제대로 로드되는지 확인

#### 2. `REPLICATE_API_TOKEN이 설정되지 않았습니다`
- Replicate 계정에서 API 토큰 발급
- `.env` 파일에 토큰 추가

#### 3. `Qdrant 연결 오류`
- Qdrant 서버가 실행 중인지 확인
- `QDRANT_URL` 설정 확인
- 컬렉션이 존재하는지 확인 (`main.py` 실행)

#### 4. `이미지 파일을 찾을 수 없습니다`
- 이미지 경로가 올바른지 확인
- 절대 경로 사용 권장

## 성능 최적화

### 1. 배치 처리
여러 사용자를 처리할 때:

```python
pipeline = BioStreamPipeline()  # 한 번만 초기화

for user in users:
    result = pipeline.run(user['data'], user['image'])
    # 결과 저장...
```

### 2. 캐싱
동일한 사용자 데이터로 반복 실행 시 RAG 결과를 캐싱할 수 있습니다.

### 3. 비동기 처리
여러 요청을 동시에 처리하려면 `asyncio`와 `aiohttp` 사용 권장.

## 제한사항

1. **이미지 크기**: 너무 큰 이미지는 base64 인코딩 시 메모리 문제 발생 가능
   - 권장 크기: 1024x1024 이하

2. **API 할당량**: 
   - Google Gemini: 분당 요청 제한 확인
   - Replicate: 유료 플랜 권장

3. **실행 시간**: 전체 파이프라인 1-2분 소요
   - RAG 검색: ~5초
   - Gemini 분석: ~10초
   - SDXL 생성: ~60초

## 개발 로드맵

- [ ] 비동기 처리 지원
- [ ] 웹 API 서버 구축 (FastAPI)
- [ ] 프론트엔드 통합
- [ ] 결과 캐싱 시스템
- [ ] A/B 테스트 프레임워크

## 라이선스
이 프로젝트는 BioStream AI의 일부입니다.

## 문의
문제가 발생하면 이슈를 등록해주세요.
