import os
import sys
import time
from fastapi import APIRouter, Depends, Header, HTTPException, UploadFile, File, Form
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy.orm import Session
from datetime import date
import json

from app.database import get_db
from app import models
from app.auth.security import verify_token

# Gemini API 임포트 (환경변수에서 API 키 가져오기)
try:
    import google.generativeai as genai
    GEMINI_AVAILABLE = True
except ImportError:
    GEMINI_AVAILABLE = False
    print("⚠️ google-generativeai 패키지가 설치되지 않았습니다. pip install google-generativeai를 실행하세요.")

# MCP tools 함수 import (MCP 서버의 함수를 사용)
try:
    # 컨테이너 환경에서 MCP 서버의 tools 모듈 import
    # PYTHONPATH가 /app으로 설정되어 있으므로 mcp_server.tools.db_tools로 import 가능
    from mcp_server.tools.db_tools import fetch_user_aging_context
    print("✅ MCP 서버의 fetch_user_aging_context 함수를 import했습니다.")
    MCP_TOOLS_AVAILABLE = True
except ImportError as e:
    print(f"⚠️ MCP 서버의 db_tools를 import할 수 없습니다: {e}")
    print("⚠️ 경로 문제일 수 있으므로 sys.path를 확인합니다.")
    
    # Fallback: 직접 경로 추가
    import sys
    import os
    mcp_server_path = os.path.join(os.path.dirname(__file__), "../../mcp_server")
    mcp_server_path = os.path.abspath(mcp_server_path)
    if mcp_server_path not in sys.path:
        sys.path.insert(0, mcp_server_path)
    
    try:
        from tools.db_tools import fetch_user_aging_context
        print("✅ Fallback 경로로 MCP 서버의 fetch_user_aging_context 함수를 import했습니다.")
        MCP_TOOLS_AVAILABLE = True
    except ImportError as e2:
        print(f"❌ MCP 서버의 함수를 import할 수 없습니다: {e2}")
        MCP_TOOLS_AVAILABLE = False
        raise ImportError("MCP 서버의 db_tools를 사용할 수 없습니다. MCP 서버가 올바르게 설정되었는지 확인하세요.")

router = APIRouter()

# 업로드 디렉터리(프로젝트 상대 경로)
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# [1] 데이터 규격 정의 (Flutter의 HealthDataPayload와 일치해야 함)
class HealthMetric(BaseModel):
    type: str
    value: str
    unit: str
    from_date: str
    to_date: str

class HealthPayload(BaseModel):
    user_id: str
    metrics: List[HealthMetric]
    timestamp: str

# [2] 데이터 수집 엔드포인트
@router.post("/collect")
async def collect_data(payload: HealthPayload):
    # 여기서 데이터를 확인합니다.
    print(f"📥 수신된 데이터 - 사용자: {payload.user_id}, 지표 수: {len(payload.metrics)}")
    
    # TODO: 여기서 kafka_producer를 통해 Kafka 토픽으로 전송하는 로직이 들어갑니다.
    # producer.send('biometrics', value=payload.dict())

    # 상위 3개 데이터만 상세 출력 (너무 많을 수 있으므로)
    for i, metric in enumerate(payload.metrics[:3]):
        print(f"  [{i+1}] 타입: {metric.type} | 값: {metric.value} {metric.unit}")
        print(f"      기간: {metric.from_date} ~ {metric.to_date}")
    
    if len(payload.metrics) > 3:
        print(f"  ... 외 {len(payload.metrics) - 3}개의 데이터 생략")
    print("="*50 + "\n")
    
    return {"status": "success", "message": f"{len(payload.metrics)}개의 데이터가 Kafka로 전송되었습니다."}

# [3] 이미지 업로드 엔드포인트
@router.post("/upload")
async def upload_image(
    user_id: int = Form(...),
    target_years: int = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    이미지 업로드 엔드포인트
    - user_id: 사용자 ID
    - target_years: 몇 년 후 모습을 보고 싶은지 (연수)
    - file: 업로드할 이미지 파일
    """
    try:
        print(f"📤 이미지 업로드 요청 - user_id: {user_id}, target_years: {target_years}, filename: {file.filename}")
        
        # 1. 파일을 디스크에 저장
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        safe_name = f"{timestamp}_{file.filename}"
        save_path = os.path.join(UPLOAD_DIR, safe_name)
        
        contents = await file.read()
        with open(save_path, "wb") as f:
            f.write(contents)
        
        print(f"✅ 파일 저장 완료: {save_path}")
        
        # 2. DB에 Lifestyle 레코드 생성 (원본 이미지 경로 저장)
        # 새로운 모델 구조에 맞게 최소한의 필드만 설정 (나머지는 설문에서 채워짐)
        lifestyle = models.Lifestyle(
            user_id=user_id,
            original_image_url=save_path,  # 저장된 파일 경로
            target_years=target_years,
            # 나머지 필드들은 모두 nullable이므로 None으로 설정 (설문에서 채워짐)
        )
        db.add(lifestyle)
        db.commit()
        db.refresh(lifestyle)
        
        print(f"✅ Lifestyle 레코드 생성 완료 - lifestyle_id: {lifestyle.id}")
        
        return {
            "message": "Image uploaded successfully",
            "filename": file.filename,
            "saved_path": save_path,
            "lifestyle_id": lifestyle.id,
            "user_id": user_id,
            "target_years": target_years
        }
    except Exception as e:
        db.rollback()
        print(f"❌ 이미지 업로드 오류: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Upload error: {str(e)}")

# [4] 사용자 lifestyle 데이터 조회 엔드포인트 (MCP tool 호출)
@router.get("/lifestyle")
async def get_lifestyle_data(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    현재 사용자의 최신 lifestyle 데이터를 조회합니다.
    MCP tool을 사용하여 DB에서 데이터를 가져옵니다.
    """
    try:
        # 인증 확인
        if not authorization:
            raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")
        
        token = authorization.replace("Bearer ", "")
        email = verify_token(token)
        if not email:
            raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
        
        user = db.query(models.User).filter(models.User.email == email).first()
        if not user:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
        
        # MCP tool 함수를 통해 lifestyle 데이터 조회
        # MCP 서버의 fetch_user_aging_context는 자체 DB 세션을 생성하므로 db 파라미터 불필요
        if not MCP_TOOLS_AVAILABLE:
            raise HTTPException(status_code=500, detail="MCP 서버 도구를 사용할 수 없습니다.")
        
        print(f"🔍 MCP 서버를 통해 사용자 {user.id}의 데이터를 조회합니다...")
        lifestyle_data = fetch_user_aging_context(user.id)
        print(f"✅ MCP 서버에서 데이터 조회 완료")
        
        if "error" in lifestyle_data:
            raise HTTPException(status_code=404, detail=lifestyle_data.get("error", "데이터를 찾을 수 없습니다."))
        
        # 이미지 경로를 서버 URL로 변환
        if "images" in lifestyle_data:
            origin = os.getenv("API_BASE_ORIGIN", "http://localhost:8080")
            if lifestyle_data["images"].get("original_image_url"):
                original_path = lifestyle_data["images"]["original_image_url"]
                # 로컬 파일 경로인 경우 서버 URL로 변환
                if os.path.exists(original_path) and UPLOAD_DIR in original_path:
                    relative_path = os.path.relpath(original_path, UPLOAD_DIR)
                    lifestyle_data["images"]["original_image_url"] = f"{origin}/data/image/{relative_path}"
            
            if lifestyle_data["images"].get("generated_image_url"):
                generated_path = lifestyle_data["images"]["generated_image_url"]
                if generated_path and os.path.exists(generated_path) and UPLOAD_DIR in generated_path:
                    relative_path = os.path.relpath(generated_path, UPLOAD_DIR)
                    lifestyle_data["images"]["generated_image_url"] = f"{origin}/data/image/{relative_path}"
        
        return {
            "success": True,
            "data": lifestyle_data
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Lifestyle 데이터 조회 오류: {str(e)}")
        raise HTTPException(status_code=500, detail=f"데이터 조회 실패: {str(e)}")

# [5] 이미지 파일 제공 엔드포인트
@router.get("/image/{file_path:path}")
async def get_image(file_path: str):
    """
    업로드된 이미지 파일을 제공합니다.
    file_path는 업로드 디렉터리 내의 상대 경로입니다.
    """
    try:
        # 보안: 파일 경로 검증
        if ".." in file_path or file_path.startswith("/"):
            raise HTTPException(status_code=400, detail="Invalid file path")
        
        # 파일 경로 구성
        image_path = os.path.join(UPLOAD_DIR, file_path)
        
        # 파일 존재 확인
        if not os.path.exists(image_path) or not os.path.isfile(image_path):
            raise HTTPException(status_code=404, detail="Image not found")
        
        # 파일 확장자 확인
        ext = os.path.splitext(image_path)[1].lower()
        media_type = None
        if ext in ['.jpg', '.jpeg']:
            media_type = 'image/jpeg'
        elif ext == '.png':
            media_type = 'image/png'
        elif ext == '.gif':
            media_type = 'image/gif'
        elif ext == '.webp':
            media_type = 'image/webp'
        else:
            media_type = 'application/octet-stream'
        
        return FileResponse(image_path, media_type=media_type)
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ 이미지 제공 오류: {str(e)}")
        raise HTTPException(status_code=500, detail=f"이미지 제공 실패: {str(e)}")

# [6] LLM을 사용하여 건강 리포트 생성 (MCP tool 사용)
@router.post("/generate-health-report")
async def generate_health_report(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """
    현재 사용자의 lifestyle 데이터를 기반으로 LLM(Gemini)이 건강 리포트를 생성합니다.
    MCP tool을 사용하여 DB에서 데이터를 가져옵니다.
    """
    try:
        # 인증 확인
        if not authorization:
            raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")
        
        token = authorization.replace("Bearer ", "")
        email = verify_token(token)
        if not email:
            raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
        
        user = db.query(models.User).filter(models.User.email == email).first()
        if not user:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
        
        # MCP tool 함수를 통해 lifestyle 데이터 조회
        # MCP 서버의 fetch_user_aging_context는 자체 DB 세션을 생성하므로 db 파라미터 불필요
        if not MCP_TOOLS_AVAILABLE:
            raise HTTPException(status_code=500, detail="MCP 서버 도구를 사용할 수 없습니다.")
        
        print(f"🔍 MCP 서버를 통해 사용자 {user.id}의 데이터를 조회합니다...")
        lifestyle_data = fetch_user_aging_context(user.id)
        print(f"✅ MCP 서버에서 데이터 조회 완료")
        
        # 디버깅: 조회된 데이터 출력
        import json
        print(f"📊 조회된 데이터: {json.dumps(lifestyle_data, indent=2, ensure_ascii=False, default=str)}")
        
        if "error" in lifestyle_data:
            raise HTTPException(status_code=404, detail=lifestyle_data.get("error", "데이터를 찾을 수 없습니다."))
        
        # Gemini API가 사용 가능한지 확인
        print(f"🔍 Gemini API 사용 가능 여부: {GEMINI_AVAILABLE}")
        if not GEMINI_AVAILABLE:
            # Gemini가 없으면 간단한 리포트 생성 (임시)
            print(f"⚠️ Gemini API가 사용 불가능합니다. 간단한 리포트를 생성합니다.")
            return {
                "success": True,
                "report": _generate_simple_report(lifestyle_data),
                "note": "Gemini API가 설정되지 않아 기본 리포트를 생성했습니다."
            }
        
        # Gemini API 키 확인
        gemini_api_key = os.getenv("GEMINI_API_KEY")
        print(f"🔑 Gemini API 키 확인: {'설정됨' if gemini_api_key else '설정되지 않음'}")
        if not gemini_api_key:
            # API 키가 없으면 간단한 리포트 생성
            print(f"⚠️ Gemini API 키가 없습니다. 간단한 리포트를 생성합니다.")
            return {
                "success": True,
                "report": _generate_simple_report(lifestyle_data),
                "note": "Gemini API 키가 설정되지 않아 기본 리포트를 생성했습니다."
            }
        
        # Gemini API 설정
        genai.configure(api_key=gemini_api_key)
        
        # 최신 모델 사용 (gemini-2.5-flash: 빠르고 저렴, gemini-2.5-pro: 고품질)
        # gemini-pro는 더 이상 지원되지 않음
        model_name = 'gemini-2.5-flash'  # 빠르고 경제적인 최신 모델
        try:
            model = genai.GenerativeModel(model_name)
        except Exception as e:
            print(f"⚠️ {model_name} 모델을 사용할 수 없습니다. gemini-flash-latest로 시도합니다: {e}")
            try:
                model_name = 'gemini-flash-latest'
                model = genai.GenerativeModel(model_name)
            except Exception as e2:
                print(f"❌ 모델을 찾을 수 없습니다. gemini-2.5-pro로 시도합니다: {e2}")
                model_name = 'gemini-2.5-pro'
                model = genai.GenerativeModel(model_name)
        
        # LLM 프롬프트 생성
        print(f"📝 프롬프트 생성 시작...")
        prompt = _create_health_report_prompt(lifestyle_data)
        print(f"📝 프롬프트 생성 완료 (길이: {len(prompt)}자)")
        
        print(f"🤖 Gemini API 호출 시작 - User ID: {user.id}, 모델: {model_name}")
        
        # Gemini API 호출
        response = model.generate_content(prompt)
        report_text = response.text
        
        print(f"✅ 건강 리포트 생성 완료")
        
        return {
            "success": True,
            "report": report_text,
            "lifestyle_data": lifestyle_data  # 리포트와 함께 데이터도 반환
        }
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ 건강 리포트 생성 오류: {str(e)}")
        # 에러가 발생해도 기본 리포트라도 반환
        try:
            if 'user' in locals() and MCP_TOOLS_AVAILABLE:
                lifestyle_data = fetch_user_aging_context(user.id)
            else:
                lifestyle_data = {}
            return {
                "success": True,
                "report": _generate_simple_report(lifestyle_data) if lifestyle_data and "error" not in lifestyle_data else "리포트 생성 중 오류가 발생했습니다.",
                "error": str(e)
            }
        except Exception as fallback_error:
            print(f"❌ Fallback 리포트 생성도 실패: {fallback_error}")
            raise HTTPException(status_code=500, detail=f"리포트 생성 실패: {str(e)}")

def _create_health_report_prompt(lifestyle_data: dict) -> str:
    """
    LLM에 전달할 프롬프트 생성 (새로운 모델 구조에 맞게 수정)
    None 값을 'N/A'로 변환하는 헬퍼 함수
    """
    def safe_get(data, *keys, default='N/A'):
        """중첩된 딕셔너리에서 안전하게 값을 가져오고 None을 처리"""
        current = data
        for key in keys:
            if isinstance(current, dict):
                current = current.get(key)
            else:
                return default
            if current is None:
                return default
        return current if current is not None else default
    
    profile = lifestyle_data.get("profile", {})
    lifestyle = lifestyle_data.get("lifestyle", {})
    bodystate = lifestyle_data.get("bodystate", {})
    skin = lifestyle_data.get("skin", {})
    target_age = lifestyle_data.get("target_age", "N/A")
    
    # None 값을 'N/A'로 변환 및 영어 코드를 한글 라벨로 변환
    outcomes = lifestyle.get('outcomes')
    outcomes_labels = {
        'wrinkle': '주름',
        'pigmentation': '색소',
        'hydration': '수분',
        'acne': '여드름',
        'redness': '홍조',
        'general_aging': '전체 노화',
    }
    if outcomes and isinstance(outcomes, list):
        outcomes_str = ', '.join([outcomes_labels.get(o, o) for o in outcomes])
    else:
        outcomes_str = 'N/A'
    
    skin_concerns = skin.get('skin_concerns')
    skin_concerns_labels = {
        'wrinkle': '주름',
        'pigmentation': '색소',
        'elasticity': '탄력',
        'dryness': '건조',
        'redness': '홍조',
        'acne': '트러블',
    }
    if skin_concerns and isinstance(skin_concerns, list):
        skin_concerns_str = ', '.join([skin_concerns_labels.get(c, c) for c in skin_concerns])
    else:
        skin_concerns_str = 'N/A'
    
    # 영어 코드를 한글 라벨로 변환하는 헬퍼
    def translate_value(value, translations):
        if value is None:
            return 'N/A'
        return translations.get(value, value) if translations else value
    
    # 각 필드별 번역 맵
    smoking_status_map = {'never': '비흡연', 'former': '과거 흡연', 'current': '현재 흡연'}
    uv_exposure_map = {'<30m': '30분 미만', '30~60': '30분~1시간', '1~2h': '1~2시간', '>2h': '2시간 이상'}
    sunscreen_freq_map = {'never': '안함', 'sometimes': '가끔', 'most_days': '대부분', 'daily_with_reapply': '매일(재도포)'}
    sunscreen_reapply_map = {'never': '안함', 'rarely': '드물게', 'sometimes': '가끔', 'often': '자주'}
    outdoor_sports_map = {'none': '안함', 'monthly': '월 1회', 'weekly': '주 1회 이상'}
    drinking_days_map = {'0': '0일', '1': '1일', '2-3': '2-3일', '4-5': '4-5일', '6-7': '6-7일'}
    caffeine_intake_map = {'0': '0잔', '1': '1잔', '2': '2잔', '3+': '3잔 이상'}
    caffeine_timing_map = {'before_noon': '오전', 'afternoon': '오후', 'evening': '저녁'}
    aerobic_map = {'0': '0회', '1-2': '1-2회', '3-4': '3-4회', '5+': '5회 이상'}
    resistance_map = {'0': '0회', '1': '1회', '2': '2회', '3+': '3회 이상'}
    skin_type_map = {'dry': '건성', 'oily': '지성', 'combination': '복합성', 'sensitive': '민감성'}
    
    prompt = f"""당신은 건강 전문가입니다. 사용자의 생활습관 데이터를 분석하여 맞춤형 건강 리포트를 작성해주세요.

## 사용자 기본 정보
- 나이: {safe_get(profile, 'age')}
- 성별: {safe_get(profile, 'gender')}

## 생활습관 정보
### 주요 목표
{outcomes_str}

### 흡연
- 흡연 상태: {translate_value(safe_get(lifestyle, 'smoking', 'smoking_status'), smoking_status_map)}
- 일일 흡연량: {safe_get(lifestyle, 'smoking', 'smoking_amount_per_day')}

### 수면
- 평일 수면시간: {safe_get(lifestyle, 'sleep', 'sleep_hours_weekday')}
- 주말 수면시간: {safe_get(lifestyle, 'sleep', 'sleep_hours_weekend')}
- 수면의 질 점수: {safe_get(lifestyle, 'sleep', 'sleep_quality_score')}

### 자외선 노출
- 야외 노출(10~16시): {translate_value(safe_get(lifestyle, 'uv', 'uv_exposure_10to16'), uv_exposure_map)}
- 선크림 사용 빈도: {translate_value(safe_get(lifestyle, 'uv', 'sunscreen_frequency'), sunscreen_freq_map)}
- 선크림 재도포: {translate_value(safe_get(lifestyle, 'uv', 'sunscreen_reapply'), sunscreen_reapply_map)}
- 야외스포츠: {translate_value(safe_get(lifestyle, 'uv', 'outdoor_sports_uv'), outdoor_sports_map)}

### 음주
- 주당 음주일수: {translate_value(safe_get(lifestyle, 'drinking', 'drinking_days_per_week'), drinking_days_map)}
- 1회 음주량: {safe_get(lifestyle, 'drinking', 'drinking_amount_per_session')}

### 스트레스 및 회복
- 스트레스 점수: {safe_get(lifestyle, 'stress', 'stress_score')}
- 카페인 섭취량: {translate_value(safe_get(lifestyle, 'stress', 'caffeine_intake'), caffeine_intake_map)}
- 카페인 섭취 시간대: {translate_value(safe_get(lifestyle, 'stress', 'caffeine_timing'), caffeine_timing_map)}

### 활동
- 유산소 운동(주당): {translate_value(safe_get(lifestyle, 'activity', 'aerobic_weekly'), aerobic_map)}
- 근력 운동(주당): {translate_value(safe_get(lifestyle, 'activity', 'resistance_weekly'), resistance_map)}

### 신체 상태
- 키: {safe_get(bodystate, 'height_cm')}
- 몸무게: {safe_get(bodystate, 'weight_kg')}

### 피부 상태
- 피부 타입: {translate_value(safe_get(skin, 'skin_type'), skin_type_map)}
- 피부 고민: {skin_concerns_str}
- 피부 만족도: {safe_get(skin, 'skin_satisfaction')}

## 보고 싶은 미래
- 미래 나이: {target_age if target_age else 'N/A'}

위 정보를 바탕으로 다음 항목을 포함한 건강 리포트를 한국어로 작성해주세요:
1. 현재 건강 상태 요약
2. 주요 건강 개선 포인트
3. 맞춤형 건강 관리 권장사항
4. 노화 예방을 위한 생활습관 개선 제안
5. 미래 나이에 대한 모습 예측

리포트는 전문적이면서도 이해하기 쉽게 작성해주세요."""
    
    # 디버깅: 생성된 프롬프트 전체 출력
    print(f"📝 생성된 프롬프트 전체:")
    print("=" * 80)
    print(prompt)
    print("=" * 80)
    
    return prompt

def _generate_simple_report(lifestyle_data: dict) -> str:
    """
    Gemini API가 없을 때 사용하는 간단한 리포트 생성 함수
    """
    profile = lifestyle_data.get("profile", {})
    lifestyle = lifestyle_data.get("lifestyle", {})
    target_age = lifestyle_data.get("target_age", "N/A")
    
    report = f"""## 건강 리포트

### 기본 정보
- 나이: {profile.get('age', 'N/A')}
- 성별: {profile.get('gender', 'N/A')}
- 목표: {target_age}

### 현재 생활습관 분석

**흡연:** {lifestyle.get('smoking', {}).get('smoking_status', 'N/A')}

**운동:**
- 일일 운동 시간: {lifestyle.get('exercise', {}).get('daily_exercise_minutes', 'N/A')}
- 운동 종류: {lifestyle.get('exercise', {}).get('exercise_type', 'N/A')}
- 운동 강도: {lifestyle.get('exercise', {}).get('exercise_intensity', 'N/A')}

**수면:**
- 평균 수면 시간: {lifestyle.get('sleep', {}).get('average_sleep_hours', 'N/A')}
- 수면의 질: {lifestyle.get('sleep', {}).get('sleep_quality', 'N/A')}

**음주:** {lifestyle.get('drinking', {}).get('drinking_frequency', 'N/A')}

**자외선 관리:**
- 자외선 차단제 사용: {lifestyle.get('uv', {}).get('sunscreen_usage', 'N/A')}

### 건강 관리 권장사항

현재 생활습관을 바탕으로 한 맞춤형 건강 관리 방법이 곧 제공될 예정입니다.
"""
    
    return report