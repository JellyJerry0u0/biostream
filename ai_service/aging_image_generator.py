# ai_service/aging_image_generator.py
"""
: 노화 영향 평가 및 이미지 생성 프롬프트 생성 (고도화 버전)
RAG 검색 결과와 사용자 설문 데이터를 결합하여 노화된 얼굴 이미지를 위한 프롬프트를 생성합니다.

고도화 기능:
- 논문의 Odds Ratio, p-value를 시각적 강도로 변환
- 부위별(눈가, 이마, 입가, 피부결) 상세 묘사
- Imagen 3 최적화 프롬프트 (hyper-realistic, 8k, medical-grade detail)
"""

import os
import re
import logging
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field
from datetime import datetime
from test_search import test_search

# Google Generative AI 라이브러리 직접 사용
import google.generativeai as genai
from google.generativeai import GenerativeModel

# PIL for image handling
from PIL import Image as PILImage
import io
import base64
import requests
from dotenv import load_dotenv

# Replicate API
try:
    import replicate
    REPLICATE_AVAILABLE = True
except ImportError:
    REPLICATE_AVAILABLE = False
    logger.warning("Replicate SDK를 사용할 수 없습니다. pip install replicate")


# .env 파일 로드
load_dotenv()

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


"""사용자 설문 데이터 구조 (backend/app/models.py의 Lifestyle 모델과 매칭)"""
@dataclass
class UserLifestyleData:
   
    # 기본 정보
    user_id: int
    age: int  # 현재 나이 (생년월일로부터 계산)
    gender: str  # male/female
    is_pregnant: Optional[bool] = None
    
    # 목표
    outcomes: List[str] = field(default_factory=list)
    target_years: int = 10  # 몇 년 후 얼굴을 보고 싶은지
    
    # Sleep & Rhythm
    sleep_hours_weekday: Optional[float] = None
    sleep_hours_weekend: Optional[float] = None
    sleep_quality_score: Optional[float] = None
    
    # UV / Photoaging
    uv_exposure_10to16: Optional[str] = None
    sunscreen_frequency: Optional[str] = None
    sunscreen_reapply: Optional[str] = None
    outdoor_sports_uv: Optional[str] = None
    
    # Alcohol & Smoking
    drinking_days_per_week: Optional[str] = None
    drinking_amount_per_session: Optional[str] = None
    smoking_status: Optional[str] = None
    smoking_amount_per_day: Optional[str] = None
    
    # Stress & Recovery
    stress_score: Optional[float] = None
    caffeine_intake: Optional[str] = None
    caffeine_timing: Optional[str] = None
    
    # Activity & Metabolic
    aerobic_weekly: Optional[str] = None
    resistance_weekly: Optional[str] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    
    # Skin 상태
    skin_type: Optional[str] = None
    skin_concerns: List[str] = field(default_factory=list)
    skin_satisfaction: Optional[float] = None

    def calculate_bmi(self) -> Optional[float]:
        """BMI 계산"""
        if self.height and self.weight:
            return self.weight / ((self.height / 100) ** 2)
        return None


@dataclass
class VisualImpactScore:
    """
    논문 근거를 기반으로 한 시각적 영향 점수 (rank_score 기반)
    
    rank_score: Qdrant가 계산한 관련도 점수 (높을수록 관련도 높음)
    text_content: 형용사 분석으로 미세 조정용
    """
    factor_name: str  # 요인 이름
    rank_score: float = 0.0  # Qdrant 관련도 점수 (주 기준)
    text_content: str = ""  # 논문 텍스트 (정성적 분석용)
    effect_description: str = ""  # 영향 설명
    
    def calculate_visual_intensity(self) -> float:
        """
        시각적 강도 점수 계산 (0.0 ~ 10.0)
        
        rank_score를 0~10 범위로 정규화하고,
        text 필드의 형용사 분석으로 미세 조정
        """
        # rank_score를 0~10 범위로 정규화
        # 일반적으로 rank_score는 0~100 범위 (높을수록 관련도 높음)
        if self.rank_score > 0:
            # 100점 만점을 10점 만점으로 변환
            base_score = min(10.0, (self.rank_score / 100.0) * 10.0)
        else:
            base_score = 5.0  # 기본값
        
        # text 필드의 형용사 분석으로 미세 조정
        text_boost = self._analyze_text_intensity()
        base_score += text_boost
        
        return min(10.0, max(0.0, base_score))
    
    def _analyze_text_intensity(self) -> float:
        """
        text 필드의 형용사를 분석하여 강도 조정값 반환 (-1.0 ~ +1.0)
        """
        if not self.text_content:
            return 0.0
        
        text_lower = self.text_content.lower()
        
        # 강한 표현
        strong_keywords = [
            '강력한', '현저한', '뚜렷한', '명확한', '유의미한', 'significant', 
            'strong', 'marked', 'pronounced', 'substantial', 'considerable'
        ]
        
        # 중간 표현
        moderate_keywords = [
            '중등도', '보통', '일부', 'moderate', 'some', 'partial'
        ]
        
        # 약한 표현
        weak_keywords = [
            '경미한', '미미한', '약한', '잠재적', 'mild', 'slight', 'weak', 
            'minimal', 'potential', 'possible'
        ]
        
        # 키워드 카운팅
        strong_count = sum(1 for kw in strong_keywords if kw in text_lower)
        moderate_count = sum(1 for kw in moderate_keywords if kw in text_lower)
        weak_count = sum(1 for kw in weak_keywords if kw in text_lower)
        
        if strong_count > 0:
            return min(1.0, strong_count * 0.5)
        elif weak_count > 0:
            return max(-1.0, -weak_count * 0.5)
        elif moderate_count > 0:
            return 0.0
        
        return 0.0
    
    def get_intensity_descriptor(self) -> str:
        """강도 점수를 한국어 설명 문구로 변환"""
        intensity = self.calculate_visual_intensity()
        
        if intensity < 2.0:
            return "미미한"
        elif intensity < 4.0:
            return "경미한"
        elif intensity < 6.0:
            return "중등도의"
        elif intensity < 8.0:
            return "심한"
        else:
            return "매우 심한"
    
    def get_confidence_level(self) -> str:
        """rank_score 기반 신뢰도 수준 반환"""
        if self.rank_score >= 80:
            return "매우 높은 관련도 (rank_score: {:.0f}점)".format(self.rank_score)
        elif self.rank_score >= 60:
            return "높은 관련도 (rank_score: {:.0f}점)".format(self.rank_score)
        elif self.rank_score >= 40:
            return "중간 관련도 (rank_score: {:.0f}점)".format(self.rank_score)
        elif self.rank_score > 0:
            return "낮은 관련도 (rank_score: {:.0f}점)".format(self.rank_score)
        else:
            return "관련도 정보 없음"


class BioStreamVisualizer:
    """노화 예측 이미지 생성을 위한 프롬프트 생성기 """
    
    def __init__(self, google_api_key: Optional[str] = None):
        self.google_api_key = google_api_key or os.getenv("GOOGLE_API_KEY")
        if not self.google_api_key:
            raise ValueError("GOOGLE_API_KEY가 설정되지 않았습니다.")
        
        genai.configure(api_key=self.google_api_key)
        
        # 사용 가능한 모델 자동 선택
        model_name = self._select_available_model()
        self.model = genai.GenerativeModel(model_name)
        logger.info(f"Gemini 모델 초기화 성공: {model_name}")
        
        self.generation_config = {
            'temperature': 0.3,
            'top_p': 0.95,
            'top_k': 40,
            'max_output_tokens': 4096,
        }
    

    def _select_available_model(self) -> str:
        """사용 가능한 Gemini 모델을 찾아서 반환 (할당량 고려)"""
        try:
            # 선호하는 모델 순서 (flash가 가장 가벼움 - 할당량 절약)
            preferred_models = [
                'gemini-1.5-flash',  # 가장 가볍고 빠름
                'gemini-flash',       # flash 계열
                'gemini-1.5-pro',     # pro 계열 (할당량 많이 사용)
                'gemini-pro'          # 기본 pro
            ]
            
            # 사용 가능한 모델 목록 가져오기
            available_models = []
            for model in genai.list_models():
                if 'generateContent' in model.supported_generation_methods:
                    # 'models/' 접두사 제거
                    model_name = model.name.replace('models/', '')
                    available_models.append(model_name)
                    logger.info(f"사용 가능한 모델 발견: {model_name}")
            
            # 선호하는 모델 중 사용 가능한 것 선택 (순서대로)
            for preferred in preferred_models:
                for available in available_models:
                    # 정확히 일치하거나 포함하는 경우
                    if preferred == available or preferred in available:
                        logger.info(f"✅ 모델 선택됨: {available} (우선순위: {preferred})")
                        return available
            
            # 선호 모델이 없으면 'flash'가 포함된 모델 우선 선택
            flash_models = [m for m in available_models if 'flash' in m.lower()]
            if flash_models:
                logger.warning(f"선호 모델 없음. Flash 모델 사용: {flash_models[0]}")
                return flash_models[0]
            
            # flash도 없으면 첫 번째 사용 가능한 모델 반환
            if available_models:
                logger.warning(f"Flash 모델 없음. 대신 {available_models[0]} 사용")
                return available_models[0]
                return available_models[0]
            
            # 모델을 찾을 수 없으면 에러
            raise ValueError("사용 가능한 Gemini 모델을 찾을 수 없습니다.")
            
        except Exception as e:
            logger.error(f"모델 선택 실패: {e}")
            # fallback to gemini-pro
            logger.warning("기본 모델 gemini-pro 사용 시도")
            return 'gemini-pro'
    
    #Step 1-2: RAG 검색
    def generate_search_queries(self, user_data: UserLifestyleData) -> List[str]:
        """사용자 데이터를 기반으로 RAG 검색 쿼리 생성"""
        queries = []
        
        if user_data.outcomes:
            for outcome in user_data.outcomes:
                outcome_map = {
                    "wrinkle": "주름",
                    "pigmentation": "색소침착",
                    "hydration": "피부수분",
                    "acne": "여드름",
                    "redness": "홍조",
                    "general_aging": "노화"
                }
                queries.append(outcome_map.get(outcome, outcome))
        
        if user_data.smoking_status == "current":
            queries.append("흡연 피부 노화")
            queries.append("담배 주름 색소침착")
        
        if user_data.drinking_days_per_week and user_data.drinking_days_per_week != "0":
            queries.append("알코올 피부 노화")
            queries.append("음주 피부 탄력")
        
        if user_data.uv_exposure_10to16 in [">2h", "1~2h"]:
            queries.append("자외선 광노화")
            queries.append("UV 피부손상")
        
        if user_data.sleep_hours_weekday and user_data.sleep_hours_weekday < 6:
            queries.append("수면부족 피부노화")
            queries.append("수면 피부재생")
        
        if user_data.stress_score and user_data.stress_score >= 7:
            queries.append("스트레스 피부노화")
            queries.append("코르티솔 피부손상")
        
        if user_data.aerobic_weekly == "0":
            queries.append("운동부족 피부노화")
        
        bmi = user_data.calculate_bmi()
        if bmi:
            if bmi < 18.5:
                queries.append("저체중 피부건강")
            elif bmi >= 25:
                queries.append("비만 피부노화")
        
        logger.info(f"생성된 검색 쿼리: {queries}")
        return queries[:10]
    
    #Qdrant vector DB에서 관련 논문 검색
    def search_evidence(self, queries: List[str], max_results_per_query: int = 3) -> List[Dict]:
        """여러 쿼리로 RAG 검색을 수행하고 결과를 집계"""
        all_results = []
        seen_paper_ids = set()
        
        for query in queries:
            try:
                results = test_search(query, limit=max_results_per_query)
                
                for result in results:
                    paper_id = result.payload.get('paper_id', '')
                    
                    if paper_id and paper_id not in seen_paper_ids:
                        seen_paper_ids.add(paper_id)
                        all_results.append({
                            'query': query,
                            'score': result.score,
                            'title': result.payload.get('title', ''),
                            'year': result.payload.get('year', ''),
                            'text': result.payload.get('text', ''),
                            'evidence_level': result.payload.get('evidence_level', ''),
                            'outcomes': result.payload.get('outcomes_ko', ''),
                            'topics': result.payload.get('topics', ''),
                            'paper_id': paper_id,
                        })
            except Exception as e:
                logger.error(f"쿼리 '{query}' 검색 실패: {e}")
                continue
        
        all_results.sort(key=lambda x: (int(x.get('evidence_level', '5')), x['score']), reverse=True)
        
        logger.info(f"총 {len(all_results)}개의 고유한 논문 검색됨")
        return all_results[:15]
    

    #검색된 논문에서 정량적 수치 추출
    def extract_quantitative_metrics(self, evidence_results: List[Dict]) -> List[VisualImpactScore]:
        """
        논문에서 rank_score를 활용하여 시각적 영향 점수로 변환
        
        Args:
            evidence_results: RAG 검색 결과 (rank_score 포함)
            
        Returns:
            시각적 영향 점수 리스트
        """
        impact_scores = []
        
        for result in evidence_results:
            text = result.get('text', '')
            title = result.get('title', '')
            topics = result.get('topics', '')
            rank_score = result.get('rank_score', 0.0)  # Qdrant 관련도 점수
            
            # 요인 이름 결정
            factor_name = topics if topics else title[:50]
            
            # rank_score 기반으로 영향 점수 생성
            impact_scores.append(VisualImpactScore(
                factor_name=factor_name,
                rank_score=rank_score,
                text_content=text,
                effect_description=text[:200]
            ))
            
            # 로그 출력
            logger.info(
                f"메트릭 추출: {factor_name[:30]} | "
                f"rank_score={rank_score:.1f} | "
                f"text_len={len(text)}"
            )
        
        logger.info(f"총 {len(impact_scores)}개 논문의 영향 점수 생성")
        return impact_scores
    
    #시각적 묘사 생성
    #Gemini가 부위별(눈가, 이마 ,볼 ,입가) 노화 묘사 생성
    #한국어 + 영문 프롬포트 동시 생성
    def generate_visual_description(
        self, 
        user_data: UserLifestyleData, 
        evidence_results: List[Dict]
    ) -> Dict[str, str]:
        """Step 3 (고도화): 노화 영향 평가 및 부위별 상세 시각적 묘사 생성"""
        logger.info("Step 3 (고도화): 논문 수치 기반 시각적 묘사 생성 시작")
        
        impact_scores = self.extract_quantitative_metrics(evidence_results)
        user_summary = self._create_user_summary(user_data)
        evidence_context = self._format_evidence_with_intensity(evidence_results, impact_scores)
        intensity_summary = self._create_intensity_summary(impact_scores)
        
        prompt = f"""당신은 노화 의학과 피부과학 전문이자  생물학적 노화 시뮬레이터입니다.
사용자의 생활습관 데이터와 의학 논문의 근거를 기반으로 **{user_data.target_years}년 후 얼굴의 시각적 변화**를 상세히 묘사해야 합니다.

## 핵심 원칙

**데이터 분석 우선순위:**
1순위: rank_score (관련도 점수) - 높을수록 사용자와 더 관련된 정보
2순위: text 필드에 포함된 형용사(강력한, 유의미한, 경미한 등)를 분석하여 영향 강도 결정
3순위: 높은 rank_score를 가진 정보는 확정적으로 반영, 낮은 점수는 보조적으로 활용

**관련도 평가:**
- rank_score 80+ : 매우 높은 관련도, 핵심 근거로 사용
- rank_score 60-79 : 높은 관련도, 주요 근거로 사용  
- rank_score 40-59 : 중간 관련도, 보조 정보로 활용
- rank_score <40 : 낮은 관련도, 참고 수준

**분석 원칙:**
- text 필드의 정성적 내용을 LLM이 해석하여 구체적 영향 도출
- rank_score를 통해 각 요인의 상대적 중요도 파악
- 높은 관련도 논문은 확정적 표현, 낮은 관련도는 '가능성' 표현 사용

## 사용자 정보
{user_summary}

## 의학 논문 근거 및 관련도 점수
{evidence_context}

## 시각적 영향 강도 요약
{intensity_summary}

## 요청사항
위 정보를 바탕으로 다음 두 가지를 생성하세요:

### 1. 노화 영향 분석 리포트
각 생활습관 요인이 피부 노화에 미치는 영향을 논문 근거와 함께 분석하세요.
- **rank_score(관련도 점수)가 높은 논문을 우선적으로 인용**
- text 필드의 형용사("강력한", "유의미한" 등)를 해석하여 영향 강도 설명
- 각 요인의 시각적 영향 강도 점수 포함 (0~10 스케일)
- rank_score 기반 신뢰도 언급 (예: "높은 관련도(85점) 논문에 따르면...")

### 2. 부위별 상세 시각적 묘사
{user_data.target_years}년 후의 얼굴을 다음 형식으로 **매우 구체적으로** 묘사하세요:

**눈가 주변 (Periorbital Area):**
- 주름(crow's feet): 개수, 깊이(mm), 길이(cm)
- 다크서클: 색상, 면적, 심도
- 처짐(ptosis): 정도, 위치

**이마 (Forehead):**
- 가로 주름: 개수(몇 개의 선), 깊이(mm)
- 세로 주름(미간): 존재 여부, 깊이

**볼/광대 (Cheeks/Zygoma):**
- 피부톤: 변화율(예: 15% 어두워짐), 색상 코드
- 색소침착: 크기, 분포, 농도
- 탄력 손실: 정도, 처짐 위치
- 모공: 크기 변화, 가시성

**입가/턱선 (Perioral/Jawline):**
- 팔자주름: 깊이(mm), 길이, 뚜렷함
- 입가 주름: 세로 주름 개수
- 턱선: 선명도 변화, 처짐 정도

**전체 피부 상태 (Overall Skin):**
- 질감: 거칠기, 균일성
- 광택: 광택도 변화율
- 수분: 건조 정도
- 전반적 인상

**정량적 변화 요약:**
- 주요 수치를 표로 정리 (예: 눈가 주름 깊이 1.8mm, 피부톤 12% 어두워짐 등)

**중요**: 신뢰도가 높은 정보(Level 1,2 또는 p<0.05)는 확정적으로 표현하고,
신뢰도가 낮은 정보는 "잠재적으로", "가능성이 있는" 등의 표현을 사용하세요.

명확하게 "## 1. 노화 영향 분석 리포트"와 "## 2. 부위별 상세 시각적 묘사"로 구분해서 작성하세요.
**수치와 구체적인 설명을 최대한 많이 포함하세요.**"""

        try:
            response = self.model.generate_content(
                prompt,
                generation_config=self.generation_config
            )
            
            # 안전한 텍스트 추출: multi-part 응답 처리
            result_text = ""
            try:
                # 단일 파트 응답 시도
                result_text = response.text
            except (ValueError, AttributeError):
                # Multi-part 응답일 경우 parts 순회
                for part in response.candidates[0].content.parts:
                    result_text += part.text
            
            report, visual_description = self._parse_llm_response(result_text)
            
            logger.info("리포트 및 부위별 시각적 묘사 생성 성공")
            
            return {
                'report': report,
                'visual_description': visual_description,
                'imagen_prompt': report.get('imagen_prompt', ''),  # 영문 프롬프트 추가
                'impact_scores': intensity_summary,
                'full_response': result_text
            }
            
        except Exception as e:
            logger.error(f"Gemini API 호출 실패: {e}")
            raise
    
    def refine_imagen_prompt(
        self, 
        user_data: UserLifestyleData,
        visual_description: str
    ) -> str:
        """ Imagen 3 최적화 프롬프트 변환"""
        logger.info("Imagen 3 최적화 프롬프트 변환 시작")
        
        future_age = user_data.age + user_data.target_years
        gender_map = {"male": "male", "female": "female", "남성": "male", "여성": "female"}
        gender_en = gender_map.get(user_data.gender, "person")
        
        prompt = f"""당신은 사진 편집 전문가이자 노화 시뮬레이터입니다.
한글로 작성된 피부 노화 묘사를 **구체적이고 상세한 영문 사진 설명**으로 변환하세요.

## 핵심 원칙

### 상세도:
- 정량적 수치를 최대한 포함 (깊이mm, 길이cm, 변화율% 등)
- 부위별 구체적 특징 명시
- 의학적으로 정확한 용어 사용

## 핵심 목표:
1. **신원 보존 (Identity Preservation):** 원본 사진의 골격, 눈매, 코의 형태를 100% 유지할 것.
2. **정밀 노화 (Precise Aging):** 단순한 '노인'이 아닌, 제공된 수치(mm, cm)에 기반한 '피부 질감의 변화'를 묘사할 것.

### 표현 규칙 (시각적 디테일 중심):
✅ **질감(Texture) 중심 표현**: distinct facial character lines, subtle shadows, textured skin surface
✅ **그림자(Shadow) 활용**: "deep enough to cast subtle shadows", "shadow-defining contours"
✅ **정량적 수치의 시각적 변환**: "1.8mm depth" → "deep enough to cast a subtle shadow"
✅ **부드러운 재정의 표현**: softly redefined contours, naturally evolved facial structure
✅ **의학/해부학 용어 유지**: periorbital area, nasolabial region, glabellar area, malar region

**변환 전략 (질감과 그림자 중심):**
- "주름 1.8mm" → "distinct facial character lines with 1.8mm depth, casting subtle shadows"
- "처진 피부" → "softly redefined facial contours with natural descent patterns"
- "탄력 손실" → "textured skin surface with reduced resilience"
- "눈가 주름" → "periorbital character lines with fine shadow details"
- "팔자주름" → "nasolabial contour lines with dimensional depth"
- "색소침착" → "hyperpigmentation and natural tonal variations"

## 출력 형식 (반드시 이 형식을 따를 것):
**A mature version of the Asian {gender_en} from the reference photo, preserving original facial identity and bone structure.** Natural facial characteristics with the following features:
- Periorbital: [한글 묘사 기반 - 질감과 그림자 중심으로 변환]
- Forehead: [한글 묘사 기반 - 시각적 디테일 강조]
- Cheeks & Skin: [한글 묘사 기반 - 수치의 시각적 변환]
- Jawline & Contours: [한글 묘사 기반 - 부드러운 재정의 표현]
Highly detailed skin pores, realistic skin imperfections, cinematic natural lighting, sharp focus on facial details, 8k, professional photography.

## 사용자 정보
- 성별: {gender_en}
- 인종: Asian
- 피부 타입: {user_data.skin_type or 'combination'}

**중요:** 나이를 명시하지 말고, 자연스러운 얼굴 특징으로만 표현하세요.

## 시각적 묘사 (한글) - 상세 정보 포함
{visual_description}

## 대체 용어 가이드 (Replicate 최적화):
- wrinkles → "distinct facial character lines with subtle shadows"
- sagging → "softly redefined facial contours"
- age spots → "hyperpigmentation and natural tonal variations"
- deep wrinkles → "prominent and well-defined facial lines"
- crow's feet → "periorbital character lines radiating from eye corners"
- loss of elasticity → "textured skin surface with reduced resilience"

## 출력 지시
위 한글 묘사를 바탕으로 **신원을 완벽히 유지하면서도 10~20년의 세월을 정밀하게 투영한 영문 프롬프트**를 작성하세요.

### 필수 포함 사항 (질감과 그림자 중심):
1. **눈가 주변 (Periorbital):**
   - Crow's feet wrinkles: 깊이(mm), 길이(cm), 개수
   - Dark under-eye circles: 색상, 정도
   - Eyelid sagging (ptosis): 정도

2. **이마 (Forehead):**
   - Horizontal wrinkles: 개수, 깊이(mm)
   - Vertical glabellar lines: 깊이(mm)

3. **볼/광대 (Cheeks & Malar):**
   - Skin tone evolution: 변화율을 자연스러운 색조 변화로 표현
   - Hyperpigmentation patterns: 크기를 자연스러운 톤 변화로 표현
   - Facial contours: 하강을 부드러운 재정의로 표현
   - Textured pores: 확대를 피부 질감으로 표현

4. **입가/턱선 (Perioral/Jawline):**
   - Nasolabial contour lines: 깊이를 입체적 그림자로 표현
   - Perioral character lines: 개수를 자연스러운 질감으로 표현
   - Jawline redefinition: 변화를 부드러운 윤곽 재정의로 표현

5. **전체 피부 (Overall):**
   - Skin texture evolution: 거칠기를 세밀한 질감 표현으로
   - Luminosity changes: 광택 감소를 자연스러운 매트 마감으로
   - Surface characteristics: 탄력 변화를 질감 특성으로

### 스타일 키워드:
- Highly detailed skin pores, realistic skin imperfections, cinematic natural lighting, sharp focus on facial details, 8k, professional photography

**중요 지시:**
1. "aging", "old" 같은 단어 없이도 피부의 '질감(Texture)'과 '그림자(Shadow)' 묘사만으로 세월이 느껴지게 하세요.
2. 수치(mm, cm)를 프롬프트에 포함하되, 그것이 시각적으로 어떻게 보일지(예: 'deep enough to cast a subtle shadow')를 묘사하세요.
3. **오직 최종 영문 프롬프트만 출력하세요. 설명이나 주석 없이.**"""

        try:
            response = self.model.generate_content(
                prompt,
                generation_config={
                    'temperature': 0.2,
                    'top_p': 0.9,
                    'top_k': 40,
                    'max_output_tokens': 1024,
                }
            )
            
            # 안전한 텍스트 추출: multi-part 응답 처리
            imagen_prompt = ""
            try:
                # 단일 파트 응답 시도
                imagen_prompt = response.text
            except (ValueError, AttributeError):
                # Multi-part 응답일 경우 parts 순회
                for part in response.candidates[0].content.parts:
                    imagen_prompt += part.text
            
            imagen_prompt = imagen_prompt.strip()
            
            cleanup_phrases = [
                "프롬프트:", "Prompt:", "Here is", "Here's", 
                "The prompt is:", "```", "**", "##"
            ]
            for phrase in cleanup_phrases:
                imagen_prompt = imagen_prompt.replace(phrase, "")
            
            imagen_prompt = imagen_prompt.strip()
            
            # 프롬프트가 비어있거나 너무 짧으면 대체 프롬프트 사용
            if not imagen_prompt or len(imagen_prompt) < 50:
                logger.warning("⚠️ Gemini가 프롬프트를 생성하지 못했습니다. visual_description 기반 대체 프롬프트를 생성합니다.")
                
                # visual_description에서 핵심 정보 추출
                gender_en = "female" if user_data.gender == "여성" else "male"
                
                # 간단한 대체 프롬프트 생성 (신원 보존 + 질감 중심)
                imagen_prompt = (
                    f"A mature version of the Asian {gender_en} from the reference photo, preserving original facial identity and bone structure. "
                    f"Natural facial characteristics with the following features: "
                    f"Periorbital: distinct character lines around eyes (depth 1-2mm, casting subtle shadows), "
                    f"Forehead: horizontal character lines (depth 1mm, 3 lines with dimensional depth), "
                    f"Cheeks: natural tonal variations (15% darker), hyperpigmentation patterns (size 3-5mm), textured pores, "
                    f"Jawline: nasolabial contour lines (depth 2-3mm), softly redefined jawline contours. "
                    f"Highly detailed skin pores, realistic skin imperfections, cinematic natural lighting, sharp focus on facial details, 8k, professional photography."
                )
                logger.info(f"✓ 대체 프롬프트 생성 완료: {imagen_prompt[:150]}...")
            
            logger.info(f"✓ Replicate SDXL 최적화 프롬프트 생성 성공\n{imagen_prompt}")
            
            return imagen_prompt
            
        except Exception as e:
            logger.error(f"Imagen 프롬프트 생성 실패: {e}")
            raise
    
    def generate_aging_face_image(
        self,
        base_image_path: str,
        imagen_prompt: str,
        visual_description: str = "",
        output_path: str = "output_aging_prediction.png"
    ) -> str:
        """Step 5: Replicate SDXL을 사용하여 노화된 얼굴 이미지 생성
        
        Args:
            base_image_path: 사용자가 업로드한 현재 얼굴 사진 경로
            imagen_prompt: Step 4에서 정제된 노화 효과 영문 프롬프트
            visual_description: Step 3의 상세한 한글 묘사 (선택적)
            output_path: 저장할 파일 경로
        
        Returns:
            생성된 이미지 파일 경로 (실패 시 빈 문자열)
        """
        logger.info(f"Step 5: 노화 얼굴 이미지 생성 시작 (Replicate SDXL)")
        logger.info(f"기본 사진: {base_image_path}")
        
        try:
            return self._generate_with_replicate(
                base_image_path=base_image_path,
                imagen_prompt=imagen_prompt,
                visual_description=visual_description,
                output_path=output_path
            )
        
        except Exception as e:
            logger.error(f"노화 얼굴 이미지 생성 실패: {e}")
            logger.error(f"오류 세부 정보: {type(e).__name__}")
            
            # 프롬프트를 파일로 저장 (외부 도구 사용 가능)
            prompt_file = "generated_prompt.txt"
            with open(prompt_file, "w", encoding="utf-8") as f:
                f.write("="*80 + "\n")
                f.write("Gemini가 생성한 노화 얼굴 이미지 프롬프트\n")
                f.write("="*80 + "\n\n")
                f.write(f"[기본 사진] {base_image_path}\n\n")
                f.write(f"[프롬프트]\n{imagen_prompt}\n\n")
                f.write("="*80 + "\n")
                f.write("추천 외부 도구:\n")
                f.write("="*80 + "\n\n")
                f.write("1. Stable Diffusion WebUI (무료, 로컬)\n")
                f.write("   - 설치: https://github.com/AUTOMATIC1111/stable-diffusion-webui\n")
                f.write("   - Image-to-Image 탭에서 위 프롬프트 사용\n")
                f.write("   - Denoising strength: 0.3-0.5 (낮을수록 원본 유지)\n\n")
                f.write("2. Replicate API (유료, $0.01/이미지)\n")
                f.write("   - 모델: stability-ai/sdxl\n")
                f.write("   - 자동화 가능 (Python SDK)\n\n")
                f.write("3. ComfyUI (무료, 로컬)\n")
                f.write("   - 설치: https://github.com/comfyanonymous/ComfyUI\n")
                f.write("   - 워크플로우 자동화 가능\n\n")
                f.write("4. Midjourney (유료, $10/월)\n")
                f.write("   - Discord에서 /imagine 사용\n")
                f.write("   - --iw 0.5 (이미지 가중치)\n\n")
            
            logger.info(f"\n✅ 프롬프트 저장됨: {prompt_file}")
            logger.info("\n=== 외부 도구로 이미지 생성하기 ===")
            logger.info("1. Stable Diffusion WebUI (추천, 무료):")
            logger.info("   https://github.com/AUTOMATIC1111/stable-diffusion-webui")
            logger.info(f"   - Image-to-Image 탭에서 {base_image_path} 업로드")
            logger.info(f"   - 프롬프트: {prompt_file} 내용 복사")
            logger.info("   - Denoising: 0.4 (원본 유지)")
            logger.info("\n2. Replicate API (자동화 가능):")
            logger.info("   pip install replicate")
            logger.info("   - 아래 코드 참고\n")
            
            raise

    
    def _generate_with_replicate(
        self,
        base_image_path: str,
        imagen_prompt: str,
        visual_description: str,
        output_path: str
    ) -> str:
        """Replicate SDXL을 사용하여 Image-to-Image 방식으로 노화 얼굴 생성"""
        logger.info(f"🎨 Replicate API 사용 (Image-to-Image)")
        
        if not REPLICATE_AVAILABLE:
            raise ImportError("Replicate SDK가 필요합니다. 설치: pip install replicate")
        
        # REPLICATE_API_TOKEN 확인
        replicate_token = os.getenv("REPLICATE_API_TOKEN")
        if not replicate_token:
            raise ValueError("REPLICATE_API_TOKEN이 .env 파일에 없습니다.")
        
        logger.info(f"✓ Replicate API 토큰 확인 완료")
        
        # Step 1: 기본 얼굴 사진 로드
        if not base_image_path or not os.path.exists(base_image_path):
            raise FileNotFoundError(f"기본 얼굴 사진을 찾을 수 없습니다: {base_image_path}")
        
        logger.info(f"📸 기본 얼굴 사진 로드: {base_image_path}")
        base_img = PILImage.open(base_image_path)
        logger.info(f"✓ 이미지 로드 성공 (크기: {base_img.size})")
        
        # Step 2: 상세 묘사를 포함하여 실사 사진 스타일로 변환
        logger.info(f"상세 노화 묘사 길이: {len(visual_description)}자")
        
        # imagen_prompt + visual_description을 결합
        combined_description = imagen_prompt
        if visual_description:
            combined_description += f"\n\nDetailed aging characteristics:\n{visual_description[:800]}"
        
        photorealistic_prompt = self._convert_visual_description_to_photorealistic(
            visual_description=combined_description,
            base_image=base_img
        )
        
        logger.info(f"프롬프트 (실사화): {photorealistic_prompt[:200]}...")
        
        # Step 3: Replicate API로 Image-to-Image 생성
        try:
            logger.info("🚀 Replicate API 호출 중 (SDXL Image-to-Image)...")
            
            # Replicate Client 생성
            client = replicate.Client(api_token=replicate_token)
            
            # 이미지를 base64로 인코딩하여 data URI 생성
            import io
            buffered = io.BytesIO()
            base_img.save(buffered, format="PNG")
            img_base64 = base64.b64encode(buffered.getvalue()).decode()
            image_data_uri = f"data:image/png;base64,{img_base64}"
            
            # SDXL Image-to-Image 모델 실행
            output = client.run(
                "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
                input={
                    "image": image_data_uri,  # 기본 얼굴 이미지
                    "prompt": photorealistic_prompt,  # 노화 프롬프트
                    "strength": 0.6,  # 변환 강도 (0.5~0.8 권장, 낮을수록 원본 유지)
                    "guidance_scale": 7.5,  # 프롬프트 충실도
                    "num_inference_steps": 30,  # 생성 품질
                    "scheduler": "K_EULER",
                    "negative_prompt": "cartoon, anime, illustration, painting, drawing, art, sketch, unrealistic, low quality",
                }
            )
            
            logger.info(f"✓ Replicate API 호출 완료")
            
            # Step 4: 결과 이미지 다운로드 및 저장
            if output and len(output) > 0:
                result_url = output[0]  # 첫 번째 이미지 URL
                logger.info(f"📥 결과 이미지 다운로드 중: {result_url}")
                
                # URL에서 이미지 다운로드
                response = requests.get(result_url)
                if response.status_code == 200:
                    result_image = PILImage.open(io.BytesIO(response.content))
                    result_image.save(output_path)
                    logger.info(f"✅ 실사 인물 이미지 생성 성공: {output_path}")
                    return output_path
                else:
                    raise ValueError(f"이미지 다운로드 실패: HTTP {response.status_code}")
            else:
                raise ValueError("Replicate API가 이미지를 생성하지 않았습니다.")
                
        except Exception as e:
            logger.error(f"Replicate API 호출 실패: {e}")
            raise
    
    def _convert_visual_description_to_photorealistic(
        self, 
        visual_description: str,
        base_image: Optional[PILImage.Image] = None
    ) -> str:
        """묘사 2 (한글 상세 노화 묘사)를 이미지와 함께 Gemini에게 전달하여 초현실적인 노화 시뮬레이션 프롬프트 생성"""
        
        logger.info("📸+📝 상세 노화 묘사와 이미지를 Gemini에게 전달하여 초현실적 노화 시뮬레이션 프롬프트 생성 중...")
        
        # Gemini 멀티모달 프롬프트 구성 - 의료 문서 스타일, 매우 상세
        conversion_prompt = f"""You are an expert in medical-grade aging documentation photography and photorealistic aging simulation.

**MISSION:**
Convert this comprehensive Korean facial aging description into a photorealistic, visually-driven English prompt for SDXL Image-to-Image aging simulation.

**CRITICAL SDXL OPTIMIZATION:**
SDXL responds to **visual intensity modifiers** and **photographic techniques**, NOT numerical measurements.

**❌ NEVER USE (AI will misinterpret):**
- Millimeter/centimeter measurements: "1.8mm", "2.5cm" (AI draws numbers as text)
- Exact counts: "4-5 lines", "3 wrinkles" (AI becomes rigid)
- Percentages: "20%", "40%" (meaningless to image models)

**✅ ALWAYS USE (Effective for SDXL):**
- **Visual Intensity Modifiers**: "deep", "prominent", "noticeable", "subtle", "faint", "pronounced", "significant", "moderate", "mild"
- **Comparative Descriptors**: "deeper than typical", "more visible", "significantly pronounced", "clearly defined"
- **Macro Photography Terms**: "macro detail", "close-up texture", "fine detail capture", "high-definition wrinkle texture"
- **Technical Camera Settings**: "85mm portrait lens", "f/4 aperture", "natural depth of field", "soft focus background"
- **Quantity Descriptors**: "multiple", "several", "numerous", "scattered", "extensive"

**IMAGE CONTEXT:**
- "This same person photographed 10 years into the future"
- "Photorealistic aging simulation"
- "Natural aging progression visible"

**INPUT - Korean Aging Description:**
{visual_description}

**CONVERSION RULES - Transform measurements to visual descriptors:**

1. **Periorbital Region (눈가)**:
   - 주름 깊이 1.8mm, 4-5개 → "**deep, prominent radial wrinkles** extending from eye corners, **multiple distinct lines**"
   - 다크서클 20% 어두움 → "**noticeably darker under-eye areas**, **prominent vascular shadowing**"
   - 눈밑 처짐 2-3mm → "**mild lower eyelid puffiness**, **subtle eye bags visible**"

2. **Forehead (이마)**:
   - 주름 깊이 1.5mm, 3개 → "**deep horizontal forehead lines**, **clearly visible at rest**, **pronounced etched grooves**"
   - 미간 주름 → "**prominent vertical glabellar lines**, **distinct "11" pattern**"

3. **Midface/Cheeks (볼/광대)**:
   - 색소침착 5-7개, 5-8mm → "**numerous scattered age spots** on cheekbones, **irregular pigmentation patches**"
   - 피부톤 12% 어두움 → "**noticeably darker overall complexion**, **yellowish undertone visible**"
   - 처짐 3-5mm → "**moderate midface volume loss**, **visible cheek descent**"
   - 모공 40% 증가 → "**significantly enlarged pores**, **prominent pore visibility**, **vertical pore elongation**"

4. **Perioral (입가)**:
   - 팔자주름 2.5mm, 4cm → "**deep nasolabial folds**, **pronounced smile lines extending downward**"
   - 입가 세로주름 5-7개 → "**multiple fine vertical lines** around mouth, **visible perioral wrinkles**"

5. **Jawline (턱선)**:
   - 명료도 20% 감소 → "**noticeably softened jawline**, **reduced definition**"
   - 턱 처짐 → "**mild jowling present**, **early jaw-neck boundary blurring**"

6. **Overall Skin**:
   - 거칠기, 광택 30% 감소 → "**rougher skin texture**, **reduced skin luminosity**, **matte appearance**"

**PHOTOGRAPHY TECHNIQUE REQUIREMENTS:**
- "Macro photography detail capture"
- "85mm portrait lens, f/4 aperture for natural depth"
- "Soft natural window lighting from 45-degree angle"
- "Real skin texture with visible pores and fine wrinkles"
- "High-resolution close-up photography"
- "Front-facing documentation style, eye-level perspective"

**EXAMPLE OUTPUT (Visual Intensity Style):**
A real photograph of this 45-year-old Korean male, 10-year aging simulation. Periorbital: deep, prominent radial wrinkles extending from eye corners, multiple distinct lines visible. Noticeably darker under-eye areas with prominent vascular shadowing. Mild lower eyelid puffiness. Forehead: deep horizontal lines clearly visible at rest, pronounced etched grooves. Prominent vertical glabellar "11" lines. Midface/cheeks: numerous scattered age spots on cheekbones with irregular borders. Noticeably darker overall complexion with yellowish undertone. Moderate midface volume loss with visible cheek descent. Significantly enlarged pores with prominent vertical elongation. Perioral: deep nasolabial folds, pronounced smile lines extending downward. Multiple fine vertical lines around mouth. Jawline: noticeably softened definition with mild jowling present. Overall: rougher skin texture, reduced luminosity, matte appearance. Macro photography detail, 85mm portrait lens f/4 aperture, soft natural window lighting, real aged skin texture visible, high-resolution close-up.

**YOUR OUTPUT (400-600 characters, pure visual intensity descriptors, NO numerical measurements):**"""

        try:
            # Gemini 모델 생성 (v1beta API 지원 모델 사용)
            model = genai.GenerativeModel("gemini-1.5-flash-latest")
            
            # 이미지가 있으면 멀티모달, 없으면 텍스트만
            if base_image:
                logger.info("✓ 이미지 + 텍스트 멀티모달 프롬프트 생성")
                
                # 추가 지시: 이미지의 얼굴 특징을 유지하면서 노화 적용
                multimodal_instruction = """

**CRITICAL - BASE FACE IMAGE PROVIDED:**
The image above shows this person's current face at baseline. You must maintain their core identity while applying 10-year aging:

**Preserve These Identity Features:**
- Exact face shape and bone structure
- Eye shape, size, and spacing
- Nose structure and proportions
- Lip shape and fullness
- Facial width-to-height ratio
- Ethnic characteristics

**Apply Aging Changes:**
Extract ALL quantitative measurements from the Korean description and apply them realistically to THIS specific person's face. The output should look like "this same person photographed 10 years later", not a generic aged face.

**Identity Check:**
If someone saw both images (current and aged), they should immediately recognize this as the same person, just 10 years older."""
                
                response = model.generate_content(
                    [conversion_prompt + multimodal_instruction, base_image],
                    generation_config={
                        'temperature': 0.15,  # 매우 낮은 온도로 정확도 향상
                        'top_p': 0.8,
                        'max_output_tokens': 1200,  # 상세 묘사 위해 증가
                    }
                )
            else:
                logger.info("✓ 텍스트 단독 프롬프트 생성")
                response = model.generate_content(
                    conversion_prompt,
                    generation_config={
                        'temperature': 0.15,
                        'top_p': 0.8,
                        'max_output_tokens': 1200,
                    }
                )
            
            # 안전한 텍스트 추출
            photorealistic_prompt = ""
            try:
                photorealistic_prompt = response.text
            except (ValueError, AttributeError):
                for part in response.candidates[0].content.parts:
                    photorealistic_prompt += part.text
            
            photorealistic_prompt = photorealistic_prompt.strip()
            
            # 불필요한 텍스트 제거 및 Portrait 패턴 교체
            cleanup_phrases = [
                "Here is", "Here's", "Output:", "YOUR OUTPUT:", "**", "```", 
                "프롬프트:", "English only:", "Pure English prompt:"
            ]
            for phrase in cleanup_phrases:
                photorealistic_prompt = photorealistic_prompt.replace(phrase, "")
            
            # Portrait 패턴을 Real photograph 패턴으로 강제 변환
            portrait_patterns = [
                ("Portrait of a", "A real photograph of this"),
                ("Portrait of an", "A real photograph of this"),
                ("portrait of a", "a real photograph of this"),
                ("portrait of an", "a real photograph of this"),
                ("Professional studio photograph", "Medical aging documentation photograph"),
                ("professional studio", "medical documentation"),
                ("studio lighting", "natural lighting")
            ]
            for old_pattern, new_pattern in portrait_patterns:
                photorealistic_prompt = photorealistic_prompt.replace(old_pattern, new_pattern)
            
            photorealistic_prompt = photorealistic_prompt.strip()
            
            # 금지어 완화 - Replicate SDXL은 의료 용어 허용
            # aging, wrinkle, sagging 등은 의료/과학 문서에서 자연스러운 표현
            safe_replacements = {
                'elderly': 'mature adult',
                'deterioration': 'natural progression',
            }
            
            found_terms = []
            for term, replacement in safe_replacements.items():
                if term in photorealistic_prompt.lower():
                    found_terms.append(term)
                    photorealistic_prompt = photorealistic_prompt.replace(term, replacement)
                    photorealistic_prompt = photorealistic_prompt.replace(term.capitalize(), replacement.capitalize())
            
            if found_terms:
                logger.info(f"ℹ️ 용어 정규화 완료: {found_terms}")
            
            logger.info(f"✓ 실사 프롬프트 생성 완료: {photorealistic_prompt[:200]}...")
            return photorealistic_prompt
            
        except Exception as e:
            logger.error(f"Gemini 직접 변환 실패: {e}")
            logger.warning("대체 프롬프트 생성 - 한글 묘사 기반 상세 변환")
            
            # 실패 시 한글 묘사에서 핵심 정량 정보를 직접 추출하여 영문 프롬프트 생성
            aging_features = []
            
            # 눈가 주름 정보 추출
            if '1.8mm' in visual_description or '주름' in visual_description or '눈가' in visual_description:
                aging_features.append("deep, prominent radial wrinkles around eyes, multiple distinct lines extending from eye corners")
            
            # 색소침착 정보 추출
            if '색소침착' in visual_description or '갈색 반점' in visual_description or '검버섯' in visual_description:
                aging_features.append("numerous scattered age spots on cheekbones, irregular pigmentation patches visible")
            
            # 이마 주름 정보 추출
            if '이마' in visual_description and '주름' in visual_description:
                aging_features.append("deep horizontal forehead lines clearly visible at rest, pronounced etched grooves")
            
            # 팔자주름 정보 추출
            if '팔자주름' in visual_description:
                aging_features.append("deep nasolabial folds, pronounced smile lines extending downward")
            
            # 처짐 정보 추출
            if '처짐' in visual_description or '탄력' in visual_description:
                aging_features.append("moderate midface volume loss with visible cheek descent, significantly enlarged pores")
            
            # 턱선 정보 추출
            if '턱선' in visual_description:
                aging_features.append("noticeably softened jawline definition, mild jowling present")
            
            # 다크서클 정보 추출
            if '다크서클' in visual_description:
                aging_features.append("noticeably darker under-eye areas, prominent vascular shadowing")
            
            # 피부톤 변화 추출
            if '피부톤' in visual_description or '황색' in visual_description:
                aging_features.append("noticeably darker overall complexion with yellowish undertone")
            
            # 조합하여 프롬프트 생성
            if aging_features:
                features_text = ", ".join(aging_features)
                fallback_prompt = (
                    f"A real photograph of this 45-year-old Korean male, 10-year natural aging simulation. "
                    f"Visible aging characteristics: {features_text}. "
                    f"Rougher skin texture with reduced luminosity. "
                    f"Macro photography detail, 85mm portrait lens f/4 aperture, "
                    f"soft natural window lighting, real aged skin texture visible, "
                    f"high-resolution close-up photography, front-facing documentation angle."
                )
            else:
                # 정보가 없으면 일반적인 노화 특징 사용 (시각적 강도 중심)
                fallback_prompt = (
                    f"A real photograph of this 45-year-old Korean male, 10-year natural aging simulation. "
                    f"Deep, prominent radial wrinkles around eyes. "
                    f"Pronounced horizontal forehead lines visible at rest. "
                    f"Numerous scattered age spots on cheeks. "
                    f"Deep nasolabial folds extending downward. "
                    f"Moderate midface volume loss with visible descent. "
                    f"Noticeably softened jawline definition. "
                    f"Rougher skin texture, enlarged pores visible, reduced skin luminosity. "
                    f"Macro photography detail, 85mm portrait lens f/4 aperture, "
                    f"soft natural lighting, real aged skin texture, high-resolution close-up."
                )
            
            logger.info(f"✓ 대체 프롬프트 생성: {fallback_prompt[:200]}...")
            return fallback_prompt
    
    def _create_user_summary(self, user_data: UserLifestyleData) -> str:
        """사용자 데이터를 요약된 텍스트로 변환"""
        summary_parts = [
            f"- 나이: {user_data.age}세",
            f"- 성별: {user_data.gender}",
            f"- 예측 기간: {user_data.target_years}년 후",
        ]
        
        if user_data.outcomes:
            summary_parts.append(f"- 주요 관심사: {', '.join(user_data.outcomes)}")
        
        if user_data.sleep_hours_weekday:
            summary_parts.append(f"- 평균 수면: 평일 {user_data.sleep_hours_weekday}시간, 주말 {user_data.sleep_hours_weekend}시간")
            if user_data.sleep_quality_score:
                summary_parts.append(f"  수면의 질: {user_data.sleep_quality_score}/10")
        
        if user_data.uv_exposure_10to16:
            summary_parts.append(f"- 자외선 노출(10-16시): {user_data.uv_exposure_10to16}")
            if user_data.sunscreen_frequency:
                summary_parts.append(f"  선크림 사용: {user_data.sunscreen_frequency}")
        
        if user_data.smoking_status:
            if user_data.smoking_status == "current" and user_data.smoking_amount_per_day:
                summary_parts.append(f"- 흡연: {user_data.smoking_amount_per_day}")
            else:
                summary_parts.append(f"- 흡연: {user_data.smoking_status}")
        
        if user_data.drinking_days_per_week:
            summary_parts.append(f"- 음주: 주 {user_data.drinking_days_per_week}일")
            if user_data.drinking_amount_per_session:
                summary_parts.append(f"  1회 음주량: {user_data.drinking_amount_per_session}")
        
        if user_data.stress_score:
            summary_parts.append(f"- 스트레스: {user_data.stress_score}/10")
        
        if user_data.caffeine_intake:
            summary_parts.append(f"- 카페인: 하루 {user_data.caffeine_intake}잔")
        
        if user_data.aerobic_weekly:
            summary_parts.append(f"- 유산소 운동: 주 {user_data.aerobic_weekly}회")
        if user_data.resistance_weekly:
            summary_parts.append(f"- 근력 운동: 주 {user_data.resistance_weekly}회")
        
        bmi = user_data.calculate_bmi()
        if bmi:
            summary_parts.append(f"- BMI: {bmi:.1f} (키 {user_data.height}cm, 몸무게 {user_data.weight}kg)")
        
        if user_data.skin_type:
            summary_parts.append(f"- 피부 타입: {user_data.skin_type}")
        if user_data.skin_concerns:
            summary_parts.append(f"- 피부 고민: {', '.join(user_data.skin_concerns)}")
        if user_data.skin_satisfaction:
            summary_parts.append(f"- 현재 피부 만족도: {user_data.skin_satisfaction}/10")
        
        return "\n".join(summary_parts)
    
    def _format_evidence_for_llm(self, evidence_results: List[Dict]) -> str:
        """논문 근거를 LLM이 이해하기 쉬운 형식으로 포맷팅"""
        if not evidence_results:
            return "관련 논문을 찾지 못했습니다."
        
        formatted_parts = []
        
        for i, result in enumerate(evidence_results, 1):
            part = f"""
### [{i}] {result['title']} ({result['year']})
- **증거 수준**: {result['evidence_level']}
- **주제**: {result['topics']}
- **결과**: {result['outcomes']}
- **내용**: {result['text'][:500]}...
- **검색 관련도**: {result['score']:.3f}
""".strip()
            formatted_parts.append(part)
        
        return "\n\n".join(formatted_parts)
    
    def _format_evidence_with_intensity(
        self, 
        evidence_results: List[Dict], 
        impact_scores: List[VisualImpactScore]
    ) -> str:
        """
        논문 근거를 rank_score 기반 관련도와 시각적 강도와 함께 포맷팅
        
        rank_score를 활용하여 관련도가 높은 논문을 강조
        """
        if not evidence_results:
            return "관련 논문을 찾지 못했습니다."
        
        formatted_parts = []
        
        for i, result in enumerate(evidence_results[:10], 1):
            # 해당 논문의 impact score 찾기
            impact_score = None
            for score in impact_scores:
                if score.factor_name in result.get('topics', '') or score.factor_name in result.get('title', ''):
                    impact_score = score
                    break
            
            # 시각적 강도 정보 구성 (rank_score 기반)
            intensity_info = ""
            if impact_score:
                intensity_value = impact_score.calculate_visual_intensity()
                intensity_desc = impact_score.get_intensity_descriptor()
                confidence = impact_score.get_confidence_level()
                
                intensity_info = f"\n- **시각적 영향 강도**: {intensity_value:.1f}/10 ({intensity_desc})"
                intensity_info += f"\n- **신뢰도**: {confidence}"
                
                # text 분석 결과 (형용사 기반)
                text_boost = impact_score._analyze_text_intensity()
                if text_boost != 0:
                    if text_boost > 0:
                        intensity_info += f"\n- **텍스트 분석**: 강한 표현 감지 (+{text_boost:.1f})"
                    else:
                        intensity_info += f"\n- **텍스트 분석**: 약한 표현 감지 ({text_boost:.1f})"
            
            part = f"""
### [{i}] {result['title']} ({result['year']})
- **증거 수준**: Level {result['evidence_level']}
- **주제**: {result['topics']}
- **결과**: {result['outcomes']}{intensity_info}
- **내용**: {result['text'][:400]}...
""".strip()
            formatted_parts.append(part)
        
        return "\n\n".join(formatted_parts)
    
    def _create_intensity_summary(self, impact_scores: List[VisualImpactScore]) -> str:
        """
        시각적 영향 강도 요약 생성 (개선 버전)
        
        모든 논문의 영향 점수를 표시 (데이터 불완전성 무관)
        """
        if not impact_scores:
            return "영향 점수를 계산할 수 없습니다."
        
        # 강도별로 정렬
        sorted_scores = sorted(impact_scores, key=lambda x: x.calculate_visual_intensity(), reverse=True)
        
        summary_parts = [f"총 {len(impact_scores)}개 요인의 시각적 영향 분석:\n"]
        
        for i, score in enumerate(sorted_scores[:10], 1):  # 상위 10개
            intensity = score.calculate_visual_intensity()
            descriptor = score.get_intensity_descriptor()
            confidence = score.get_confidence_level()
            
            summary = f"{i}. **{score.factor_name}**: {intensity:.1f}/10 ({descriptor}) | {confidence}"
            
            summary_parts.append(summary)
        
        return "\n".join(summary_parts)
    
    def _parse_llm_response(self, response_text: str) -> tuple:
        """LLM 응답을 리포트, 시각적 묘사, 영문 프롬프트로 분리"""
        # Section 2: 부위별 상세 시각적 묘사 (한국어)
        section2_markers = [
            "## 2. 시각적 묘사",
            "## 2. 부위별 상세 시각적 묘사",
            "2. 부위별 상세 시각적 묘사"
        ]
        
        # Section 3: SDXL Image Prompt (영문)
        section3_markers = [
            "## 3. SDXL Image Prompt",
            "## 3. Stable Diffusion 이미지 프롬프트",
            "3. SDXL Image Prompt",
            "## SDXL Image Prompt"
        ]
        
        split_index_2 = -1
        split_index_3 = -1
        
        # Section 2 찾기
        for marker in section2_markers:
            if marker in response_text:
                split_index_2 = response_text.index(marker)
                break
        
        # Section 3 찾기
        for marker in section3_markers:
            if marker in response_text:
                split_index_3 = response_text.index(marker)
                break
        
        # 분리
        if split_index_2 != -1 and split_index_3 != -1:
            # 3개 섹션 모두 존재
            report_text = response_text[:split_index_2].strip()
            visual_description = response_text[split_index_2:split_index_3].strip()
            imagen_prompt = response_text[split_index_3:].strip()
            
            # Section 3 헤더 제거하고 순수 프롬프트만 추출
            for marker in section3_markers:
                imagen_prompt = imagen_prompt.replace(marker, "").strip()
            
            # 코드 블록 제거
            imagen_prompt = imagen_prompt.replace("```", "").strip()
            
            return {'report': report_text, 'imagen_prompt': imagen_prompt}, visual_description
            
        elif split_index_2 != -1:
            # Section 2만 존재 (Section 3 없음)
            report_text = response_text[:split_index_2].strip()
            visual_description = response_text[split_index_2:].strip()
            logger.warning("SDXL 프롬프트(Section 3)를 찾을 수 없습니다. 대체 프롬프트를 생성합니다.")
            
            return {'report': report_text, 'imagen_prompt': ''}, visual_description
        else:
            # 분리 실패
            logger.warning("섹션 분리 실패. 전체를 리포트로 사용합니다.")
            return {'report': response_text, 'imagen_prompt': ''}, "시각적 묘사를 추출할 수 없습니다."


def generate_aging_image_prompt_pipeline(
    user_data: UserLifestyleData,
    base_image_path: Optional[str] = None,
    generate_image: bool = False,
    output_image_path: str = "output_aging_prediction.png"
) -> Dict:
    """전체 파이프라인: 사용자 데이터 → RAG 검색 → 노화 분석 → Replicate SDXL 이미지 생성
    
    Args:
        user_data: 사용자 생활습관 데이터
        base_image_path: 사용자가 업로드한 현재 얼굴 사진 경로 (필수!)
        generate_image: 이미지를 실제로 생성할지 여부 (False일 경우 프롬프트까지만 생성)
        output_image_path: 생성된 이미지 저장 경로
        
    Returns:
        파이프라인 결과 (리포트, 시각적 묘사, 프롬프트, 이미지 경로 등)
    """
    logger.info("=== 노화 이미지 생성 파이프라인 시작 ===")
    
    visualizer = BioStreamVisualizer()
    
    # Step 1-2: 검색 쿼리 생성 및 RAG 검색
    queries = visualizer.generate_search_queries(user_data)
    evidence_results = visualizer.search_evidence(queries)
    
    # Step 3: 노화 영향 평가 및 시각적 묘사 생성 (한국어 리포트 + 영문 프롬프트 동시 생성)
    step3_result = visualizer.generate_visual_description(user_data, evidence_results)
    logger.info("Step 3 완료: 리포트 및 부위별 시각적 묘사 생성 성공")
    
    # Step 4: 영문 프롬프트 확인 및 대체 생성 (필요시)
    imagen_prompt = step3_result.get('imagen_prompt', '').strip()
    
    if not imagen_prompt or len(imagen_prompt) < 50:
        logger.warning("⚠️ Gemini가 영문 프롬프트를 생성하지 못했습니다. refine_imagen_prompt()로 재생성합니다.")
        imagen_prompt = visualizer.refine_imagen_prompt(user_data, step3_result['visual_description'])
        logger.info("✓ 대체 프롬프트 생성 완료")
    else:
        logger.info(f"✓ Step 3에서 영문 프롬프트 생성 완료 (길이: {len(imagen_prompt)}자)")
        logger.info("Step 4 생략: 이미 영문 프롬프트가 생성되었습니다 (API 호출 절약)")
    
    # Step 5: Image-to-Image 노화 얼굴 생성 (선택적)
    image_path = None
    if generate_image:
        if not base_image_path:
            logger.error("❌ 기본 사진이 제공되지 않았습니다!")
            logger.warning("노화 얼굴 생성을 위해서는 사용자 얼굴 사진이 필요합니다.")
            logger.warning("프롬프트만 반환합니다.")
        else:
            try:
                image_path = visualizer.generate_aging_face_image(
                    base_image_path=base_image_path,
                    imagen_prompt=imagen_prompt,
                    visual_description=step3_result['visual_description'],
                    output_path=output_image_path
                )
                logger.info(f"Step 5 완료: 노화 얼굴 이미지 생성 성공 - {image_path}")
            except Exception as e:
                logger.warning(f"Step 5 실패: 이미지 생성 실패 ({e}). 프롬프트만 반환합니다.")
                image_path = None
    else:
        logger.info("Step 5 생략: generate_image=False로 설정됨")
    
    logger.info("=== 파이프라인 완료 ===")
    
    return {
        'report': step3_result['report'],
        'visual_description': step3_result['visual_description'],
        'imagen_prompt': imagen_prompt,
        'image_path': image_path,
        'base_image_path': base_image_path,
        'impact_scores': step3_result['impact_scores'],
        'evidence_count': len(evidence_results),
        'queries_used': queries,
        'full_llm_response': step3_result['full_response']
    }


if __name__ == "__main__":
    sample_user = UserLifestyleData(
        user_id=1,
        age=35,
        gender="male",
        outcomes=["wrinkle", "pigmentation", "general_aging"],
        target_years=10,
        sleep_hours_weekday=5.5,
        sleep_hours_weekend=7.0,
        sleep_quality_score=6.0,
        uv_exposure_10to16=">2h",
        sunscreen_frequency="sometimes",
        sunscreen_reapply="never",
        outdoor_sports_uv="weekly",
        drinking_days_per_week="2-3",
        drinking_amount_per_session="소주 반병",
        smoking_status="current",
        smoking_amount_per_day="반갑",
        stress_score=8.0,
        caffeine_intake="3+",
        caffeine_timing="evening",
        aerobic_weekly="0",
        resistance_weekly="0",
        height=175.0,
        weight=75.0,
        skin_type="combination",
        skin_concerns=["wrinkle", "pigmentation", "dryness"],
        skin_satisfaction=5.0
    )
    
    print("\n" + "="*80)
    print("노화 이미지 생성 파이프라인 테스트")
    print("="*80)
    
    # 테스트: 프롬프트만 생성 (이미지 생성 X)
    result = generate_aging_image_prompt_pipeline(
        user_data=sample_user,
        generate_image=False  # 이미지 생성하지 않고 프롬프트만 생성
    )
    
    print("\n✅ 파이프라인 실행 완료!")
    print(f"\n📊 검색된 논문 수: {result['evidence_count']}")
    print(f"📝 사용된 쿼리: {result['queries_used'][:3]}...")
    print(f"\n📋 리포트 길이: {len(result['report'])}자")
    print(f"🎨 시각적 묘사 길이: {len(result['visual_description'])}자")
    print(f"🖼️ Imagen 프롬프트 길이: {len(result['imagen_prompt'])}자")
    
    print("\n" + "="*80)
    print("📄 생성된 Imagen 프롬프트 (처음 500자):")
    print("="*80)
    print(result['imagen_prompt'][:500])
    print("\n... (후략)")
    
    print("\n" + "="*80)
    print("✅ 테스트 완료!")
    print("="*80)
