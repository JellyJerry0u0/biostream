# BioStream Image Generation - 파일 구조

## 📁 파일 역할

### 핵심 파일 (사용 중)
```
image/
├── biostream_pipeline.py          # ⭐ 메인 파이프라인 (RAG → Gemini → SDXL)
├── sample_user_data.py            # ⭐ 테스트용 샘플 데이터 (하드코딩)
├── test_with_pipeline.py          # ⭐ 통합 테스트 스크립트
└── sample_face.jpg                # ⭐ 테스트용 얼굴 이미지
```

### 참고 파일 (레거시)
```
image/
├── aging_image_generator.py       # 📚 이전 버전 (참고용, 사용 안 함)
├── test_aging_with_image.py       # 📚 이전 테스트 (참고용)
└── test_pipeline.py               # 📚 기본 테스트 (이미지 생성 X)
```

### 문서
```
image/
├── BIOSTREAM_PIPELINE_GUIDE.md    # 📖 파이프라인 사용 가이드
├── TEST_GUIDE.md                  # 📖 전체 테스트 가이드
└── TEST_STRUCTURE.md              # 📖 이 파일
```

## 🚀 사용 방법

### 1. 샘플 데이터 확인
```python
# sample_user_data.py에서 프로필 확인
python sample_user_data.py
```

**출력:**
```
[high_risk]
나이: 35세
성별: 남성
흡연: 예
음주: 예
스트레스: 8/10
...

[healthy]
나이: 30세
성별: 여성
흡연: 아니오
...
```

### 2. 테스트 실행
```powershell
python test_with_pipeline.py
```

**메뉴:**
```
1. 기본 테스트 (고위험 프로필 + 실제 이미지 생성)
2. 다중 프로필 테스트 (프롬프트만)
3. 사용자 정의 프로필 테스트
4. 종료
```

### 3. 코드에서 직접 사용
```python
from biostream_pipeline import BioStreamPipeline
from sample_user_data import get_profile

# 프로필 로드
user_data = get_profile('high_risk')  # 또는 'healthy', 'moderate_risk' 등

# 파이프라인 실행
pipeline = BioStreamPipeline()
result = pipeline.run(
    user_data=user_data,
    image_path="sample_face.jpg"
)

# 결과 사용
print(result['image_url'])         # 생성된 이미지 URL
print(result['korean_report'])     # 한글 분석 리포트
print(result['raw_prompt'])        # 영문 프롬프트
```

## 📊 데이터 구조

### 입력: user_data (딕셔너리)
```python
{
    'age': 35,                      # 나이
    'gender': '남성',               # 성별
    'smoking': True,                # 흡연 여부
    'drinking': True,               # 음주 여부
    'stress_level': 8,              # 스트레스 (0-10)
    'sleep_hours': 5,               # 수면 시간
    'exercise_frequency': 1,        # 운동 빈도 (회/주)
    'uv_exposure': True,            # 자외선 노출
    'sunscreen_use': False,         # 선크림 사용
}
```

### 출력: result (딕셔너리)
```python
{
    'image_url': 'https://...',     # 생성된 이미지 URL
    'korean_report': '...',         # 한글 분석 리포트
    'evidence': [...],              # 논문 근거 리스트
    'raw_prompt': '...',            # SDXL용 영문 프롬프트
}
```

## 🎯 테스트 시나리오

### 시나리오 1: 고위험 프로필 (high_risk)
- 35세 남성
- 흡연 ✅, 음주 ✅
- 수면 부족 (5시간)
- 높은 스트레스 (8/10)
- 운동 부족 (1회/주)
- **예상 결과**: 심한 노화 징후 (주름, 색소침착, 탄력 저하)

### 시나리오 2: 건강한 프로필 (healthy)
- 30세 여성
- 금연, 금주
- 충분한 수면 (8시간)
- 낮은 스트레스 (3/10)
- 규칙적 운동 (5회/주)
- **예상 결과**: 경미한 노화 징후

### 시나리오 3: 중간 위험 (moderate_risk)
- 40세 남성
- 금연, 음주 ✅
- 보통 수면 (6.5시간)
- 중간 스트레스 (6/10)
- 가끔 운동 (2회/주)
- **예상 결과**: 중등도 노화 징후

## 🔄 개발 워크플로우

### 1. 샘플 데이터 추가
`sample_user_data.py`에 새 프로필 추가:
```python
NEW_PROFILE = {
    'age': 50,
    'gender': '여성',
    ...
}

ALL_PROFILES['new_profile'] = NEW_PROFILE
```

### 2. 테스트
```python
user_data = get_profile('new_profile')
result = pipeline.run(user_data, image_path)
```

### 3. 프로덕션 전환
하드코딩 데이터 대신 DB에서 로드:
```python
# backend/app/services/aging_service.py
from ai_service.image.biostream_pipeline import BioStreamPipeline

def generate_aging_image(user_id: int, image_path: str):
    # DB에서 설문 데이터 로드
    lifestyle = db.query(Lifestyle).filter_by(user_id=user_id).first()
    
    user_data = {
        'age': calculate_age(lifestyle.birth_date),
        'gender': lifestyle.gender,
        'smoking': lifestyle.smoking_status == 'current',
        'drinking': lifestyle.drinking_days_per_week > 0,
        ...
    }
    
    # 파이프라인 실행
    pipeline = BioStreamPipeline()
    result = pipeline.run(user_data, image_path)
    
    return result
```

## 🐛 디버깅

### 문제: 프로필이 반영되지 않음
**확인:**
```python
# sample_user_data.py 수정 후
python sample_user_data.py  # 변경사항 확인
```

### 문제: Qdrant 연결 실패
**해결:**
```powershell
docker ps | findstr qdrant
docker-compose up -d qdrant
```

### 문제: 이미지 생성 실패
**확인:**
1. Replicate API 토큰 유효성
2. 계정 잔액 (최소 $0.01)
3. 네트워크 연결

## 📝 다음 단계

1. **DB 연동**: `sample_user_data.py` → DB 쿼리로 대체
2. **API 엔드포인트**: FastAPI로 REST API 구축
3. **배치 처리**: 여러 사용자 동시 처리
4. **결과 저장**: S3/DB에 이미지 및 리포트 저장

---

**문의**: 이슈 등록 또는 팀 채널
