# 🧪 BioStream 노화 시뮬레이터 테스트 가이드

## 현재 상태 확인

### ✅ 확인 완료 사항

1. **설문 데이터**: `aging_image_generator.py` 하단에 하드코딩됨 (1401-1432줄)
   - 35세 남성, 흡연자, 음주자, 수면 부족 등 고위험 프로필
   - `generate_image=False`로 설정되어 **프롬프트만 생성**

2. **Qdrant**: Docker Compose에서 실행 중
   - 포트: 6333 (HTTP), 6334 (gRPC)
   - 볼륨: `qdrant_data`
   - 컨테이너명: `biostream_qdrant`

3. **API 키**: `.env` 파일에 설정됨
   - `GOOGLE_API_KEY`: Gemini API 키
   - `REPLICATE_API_TOKEN`: Replicate API 토큰

4. **샘플 이미지**: `sample_face.jpg` 존재 확인 ✅

## 📋 테스트 전 체크리스트

### 1. Docker 확인
```powershell
# Docker 실행 확인
docker ps

# Qdrant 컨테이너 확인
docker ps | findstr qdrant

# 출력 예시:
# biostream_qdrant   qdrant/qdrant:latest   Up 2 hours   6333-6334/tcp
```

**Qdrant가 없다면 시작:**
```powershell
cd C:\Users\82102\BioStream
docker-compose up -d qdrant
```

### 2. Qdrant 데이터 확인
```powershell
# Python 환경 활성화
& .\.venv\Scripts\Activate.ps1

# Qdrant 컬렉션 확인
cd ai_service
python -c "from qdrant_client import QdrantClient; c = QdrantClient('http://localhost:6333'); print(c.get_collections())"
```

**출력 예시:**
```
collections=[CollectionDescription(name='biostream_v1', points_count=1234)]
```

**컬렉션이 없다면 데이터 적재:**
```powershell
cd ai_service
python main.py  # biostream_corpus_final.csv를 Qdrant에 적재
```

### 3. 이미지 파일 확인
```powershell
# sample_face.jpg 존재 확인
ls ai_service\image\sample_face.jpg
```

**이미지가 없다면:**
- `ai_service/image/` 폴더에 테스트용 얼굴 사진 배치
- 파일명: `sample_face.jpg`
- 권장 크기: 512x512 ~ 1024x1024 픽셀

### 4. API 할당량 확인
- **Google Gemini**: https://aistudio.google.com/app/apikey
- **Replicate**: https://replicate.com/account/api-tokens
  - 요금: ~$0.01/이미지 (SDXL)

## 🚀 테스트 실행

### 방법 1: 자동화 스크립트 (추천)
```powershell
# Python 환경 활성화
& .\.venv\Scripts\Activate.ps1

# 테스트 스크립트 실행
cd ai_service\image
python test_aging_with_image.py
```

**메뉴:**
```
1. 기본 테스트 (sample_face.jpg + 기본 설문 데이터)
2. 사용자 정의 테스트 (직접 설문 입력)
3. 종료
```

**1번 선택 시:**
- 자동으로 환경 체크 → RAG 검색 → Gemini 분석 → Replicate 이미지 생성
- 소요 시간: 1-3분
- 결과 파일:
  - `output_aged_face_test.png` (노화 이미지)
  - `test_result.txt` (전체 리포트)

### 방법 2: 수동 실행 (디버깅용)
```powershell
cd ai_service\image
python
```

```python
# Python 인터프리터에서
import sys
from pathlib import Path
sys.path.insert(0, str(Path.cwd().parent))

from aging_image_generator import UserLifestyleData, generate_aging_image_prompt_pipeline

# 테스트 데이터
user = UserLifestyleData(
    user_id=1,
    age=35,
    gender="male",
    outcomes=["wrinkle", "pigmentation"],
    target_years=10,
    sleep_hours_weekday=5.5,
    smoking_status="current",
    drinking_days_per_week="2-3",
    stress_score=8.0,
    aerobic_weekly="0",
    height=175.0,
    weight=75.0,
    skin_type="combination",
    skin_concerns=["wrinkle"]
)

# 파이프라인 실행 (이미지 생성 포함)
result = generate_aging_image_prompt_pipeline(
    user_data=user,
    base_image_path="sample_face.jpg",
    generate_image=True,
    output_image_path="output_test.png"
)

# 결과 확인
print(f"이미지: {result['image_path']}")
print(f"논문 수: {result['evidence_count']}")
```

## 📊 예상 결과

### 성공 시 출력:
```
================================================================================
✅ 테스트 성공!
================================================================================

📊 통계:
   - 검색된 논문: 12개
   - 사용된 쿼리: 8개
   - 리포트 길이: 2,345자
   - 영문 프롬프트 길이: 456자

🖼️ 생성된 이미지:
   입력: C:\Users\82102\BioStream\ai_service\image\sample_face.jpg
   출력: C:\Users\82102\BioStream\ai_service\image\output_aged_face_test.png

   → 이미지를 확인하세요: C:\...\output_aged_face_test.png

📄 한글 리포트 미리보기:
--------------------------------------------------------------------------------
## 1. 노화 영향 분석 리포트

**흡연 (시각적 영향: 8.5/10, 매우 심함)**
높은 관련도(87점) 논문에 따르면, 흡연은 피부 노화의 주요 원인입니다...
```

### 생성 파일:
1. **output_aged_face_test.png**: 10년 후 노화 시뮬레이션 이미지
2. **test_result.txt**: 한글 리포트 + 영문 프롬프트 + 상세 묘사

## ❗ 문제 해결

### 오류 1: Qdrant 연결 실패
```
❌ Qdrant 연결 실패: Connection refused
```

**해결:**
```powershell
docker-compose up -d qdrant
timeout /t 10  # 10초 대기
python test_aging_with_image.py
```

### 오류 2: 컬렉션 없음
```
❌ Collection 'biostream_v1' not found
```

**해결:**
```powershell
cd ai_service
python main.py  # 논문 데이터 적재
```

### 오류 3: API 할당량 초과
```
❌ Google API Error: Quota exceeded
```

**해결:**
- Gemini API 할당량 확인: https://aistudio.google.com/
- 24시간 후 재시도 또는 유료 플랜 업그레이드

### 오류 4: Replicate 요금 부족
```
❌ Replicate API Error: Insufficient credits
```

**해결:**
- Replicate 계정에 크레딧 추가: https://replicate.com/account
- 약 $0.01/이미지 (최소 $5 충전 권장)

### 오류 5: 이미지 로드 실패
```
❌ FileNotFoundError: sample_face.jpg
```

**해결:**
```powershell
# 이미지 경로 확인
ls ai_service\image\sample_face.jpg

# 없으면 테스트용 얼굴 사진 배치
# 또는 다른 이미지 사용
python test_aging_with_image.py
# → 1번 대신 2번 선택 후 이미지 경로 직접 입력
```

## 🎯 다음 단계

### 1. 프론트엔드 통합
```python
# Flutter/Dart에서 호출할 API 엔드포인트 구축
# backend/app/api/ 폴더에 추가

from fastapi import APIRouter, UploadFile, File
from ai_service.image.aging_image_generator import generate_aging_image_prompt_pipeline

router = APIRouter()

@router.post("/generate-aging-image")
async def generate_aging(
    user_data: dict,
    face_image: UploadFile = File(...)
):
    # 파이프라인 호출
    result = generate_aging_image_prompt_pipeline(...)
    return result
```

### 2. 설문 데이터 동적 로드
```python
# backend/app/models.py의 Lifestyle 모델에서 데이터 로드
from backend.app.models import Lifestyle

def get_user_lifestyle(user_id: int) -> UserLifestyleData:
    # DB에서 설문 데이터 가져오기
    lifestyle = session.query(Lifestyle).filter_by(user_id=user_id).first()
    
    # UserLifestyleData로 변환
    return UserLifestyleData(
        user_id=lifestyle.user_id,
        age=calculate_age(lifestyle.birth_date),
        gender=lifestyle.gender,
        ...
    )
```

### 3. 배치 처리
```python
# 여러 사용자를 한 번에 처리
for user_id in user_ids:
    user_data = get_user_lifestyle(user_id)
    result = generate_aging_image_prompt_pipeline(user_data, ...)
    save_to_db(user_id, result)
```

## 📚 참고 자료

- **Replicate SDXL 문서**: https://replicate.com/stability-ai/sdxl
- **Qdrant 문서**: https://qdrant.tech/documentation/
- **Gemini API 가이드**: https://ai.google.dev/gemini-api/docs
- **프로젝트 구조**: [../BIOSTREAM_PIPELINE_GUIDE.md](BIOSTREAM_PIPELINE_GUIDE.md)

## 💡 팁

1. **테스트 모드**: `generate_image=False`로 설정하면 API 비용 없이 프롬프트만 생성
2. **prompt_strength 조정**: 0.5~0.58 사이로 설정하여 Identity 유지
3. **negative_prompt 활용**: 만화/애니메이션 스타일 방지
4. **배치 크기 조정**: 한 번에 많은 이미지를 생성하면 Replicate 할당량 주의

---

**문의**: 이슈 등록 또는 팀 채널에 질문
