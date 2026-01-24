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

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


@dataclass
class UserLifestyleData:
    """사용자 설문 데이터 구조 (backend/app/models.py의 Lifestyle 모델과 매칭)"""
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
    논문 근거를 기반으로 한 시각적 영향 점수 (개선 버전)
    
    우선순위:
    1순위: effect_value (정량적 수치)
    2순위: text 필드의 형용사 분석 (강력한, 유의미한 등)
    3순위: p_value < 0.05 또는 evidence_level 1,2인 정보는 적극 반영
    """
    factor_name: str  # 요인 이름
    evidence_level: Optional[str] = None  # "1", "2", "3", "4", "5"
    p_value: Optional[float] = None  # p-value (있으면 사용)
    effect_value: Optional[float] = None  # 효과 크기 수치 (있으면 최우선)
    text_content: str = ""  # 논문 텍스트 (정성적 분석용)
    effect_description: str = ""  # 영향 설명
    
    def calculate_visual_intensity(self) -> float:
        """
        시각적 강도 점수 계산 (0.0 ~ 10.0)
        
        우선순위 로직:
        1. effect_value가 있으면 해당 수치에 비례하여 점수 산정
        2. 없으면 evidence_level 기반으로 기본 점수 설정
        3. p_value가 있으면 추가 가중치 적용
        4. text 필드의 형용사 분석으로 미세 조정
        """
        base_score = 5.0  # 기본값
        
        # 1순위: effect_value 기반 점수 산정
        if self.effect_value is not None:
            # effect_value를 0~10 범위로 정규화
            # 일반적으로 effect size: 0.2(small), 0.5(medium), 0.8+(large)
            if self.effect_value < 0.2:
                base_score = 2.0
            elif self.effect_value < 0.5:
                base_score = 4.0 + (self.effect_value - 0.2) * 6.67  # 0.2~0.5 → 4~6
            elif self.effect_value < 0.8:
                base_score = 6.0 + (self.effect_value - 0.5) * 6.67  # 0.5~0.8 → 6~8
            else:
                base_score = min(10.0, 8.0 + (self.effect_value - 0.8) * 5.0)  # 0.8+ → 8~10
        
        # 2순위: evidence_level 기반 점수 (effect_value 없을 때)
        elif self.evidence_level is not None:
            level_scores = {
                "1": 8.0,  # Meta-analysis: 가장 높은 가중치
                "2": 6.5,  # RCT/Cohort: 중간 가중치
                "3": 5.0,  # Case-control
                "4": 3.5,  # Case report/Expert opinion: 낮은 가중치
                "5": 2.0   # 낮은 신뢰도
            }
            base_score = level_scores.get(str(self.evidence_level), 5.0)
        
        # 3순위: p_value 가중치 (있으면 적용)
        if self.p_value is not None:
            if self.p_value < 0.001:
                confidence_multiplier = 1.3  # 매우 유의미
            elif self.p_value < 0.01:
                confidence_multiplier = 1.2
            elif self.p_value < 0.05:
                confidence_multiplier = 1.1  # 유의미
            else:
                confidence_multiplier = 0.9  # 유의미하지 않음
            
            base_score *= confidence_multiplier
        
        # 4순위: text 필드의 형용사 분석으로 미세 조정
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
        """근거의 신뢰도 수준 반환"""
        # p-value가 있으면 1순위로 참고
        if self.p_value is not None:
            if self.p_value < 0.001:
                return "매우 높은 신뢰도"
            elif self.p_value < 0.01:
                return "높은 신뢰도"
            elif self.p_value < 0.05:
                return "신뢰할 수 있는"
            else:
                return "낮은 신뢰도"
        
        # p-value 없으면 evidence_level 기준
        if self.evidence_level:
            level_confidence = {
                "1": "매우 높은 신뢰도 (메타분석)",
                "2": "높은 신뢰도 (RCT/코호트)",
                "3": "중간 신뢰도",
                "4": "낮은 신뢰도",
                "5": "매우 낮은 신뢰도"
            }
            return level_confidence.get(str(self.evidence_level), "불명확")
        
        return "불명확"


class BioStreamVisualizer:
    """노화 예측 이미지 생성을 위한 프롬프트 생성기 (고도화 버전)"""
    
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
    
    def extract_quantitative_metrics(self, evidence_results: List[Dict]) -> List[VisualImpactScore]:
        """
        논문에서 정량적/정성적 정보를 추출하여 시각적 영향 점수로 변환 (개선 버전)
        
        우선순위:
        1. effect_value 추출 시도
        2. p_value 추출 시도
        3. evidence_level 활용 (항상 존재)
        4. text 필드의 형용사 분석
        
        Args:
            evidence_results: RAG 검색 결과
            
        Returns:
            시각적 영향 점수 리스트 (데이터가 불완전해도 버리지 않음)
        """
        impact_scores = []
        
        for result in evidence_results:
            text = result.get('text', '')
            title = result.get('title', '')
            topics = result.get('topics', '')
            evidence_level = result.get('evidence_level', '5')
            
            # 1순위: effect_value 추출 (effect size, Cohen's d 등)
            effect_value = None
            effect_patterns = [
                r'effect\s+size[=:\s]+(\d+\.?\d*)',
                r'cohen\'?s?\s+d[=:\s]+(\d+\.?\d*)',
                r'd[=:\s]+(\d+\.?\d*)',
                r'효과\s*크기[=:\s]+(\d+\.?\d*)'
            ]
            
            for pattern in effect_patterns:
                match = re.search(pattern, text, re.IGNORECASE)
                if match:
                    effect_value = float(match.group(1))
                    logger.info(f"effect_value 추출 성공: {effect_value} from {title[:50]}")
                    break
            
            # 2순위: p-value 추출
            p_value = None
            p_patterns = [
                r'p[=:\s]*<\s*(\d+\.?\d*)',
                r'p[=:\s]+(\d+\.?\d*)',
                r'p-value[=:\s]+(\d+\.?\d*)',
                r'p\s*=\s*(\d+\.?\d+)'
            ]
            
            for pattern in p_patterns:
                match = re.search(pattern, text, re.IGNORECASE)
                if match:
                    p_value = float(match.group(1))
                    logger.info(f"p-value 추출 성공: {p_value} from {title[:50]}")
                    break
            
            # 요인 이름 결정
            factor_name = topics if topics else title[:50]
            
            # **데이터가 불완전해도 버리지 않음**
            # effect_value, p_value가 없어도 evidence_level과 text는 있음
            impact_scores.append(VisualImpactScore(
                factor_name=factor_name,
                evidence_level=evidence_level,
                p_value=p_value,
                effect_value=effect_value,
                text_content=text,
                effect_description=text[:200]
            ))
            
            # 로그 출력
            logger.info(
                f"메트릭 추출: {factor_name[:30]} | "
                f"Level={evidence_level} | "
                f"effect={effect_value} | "
                f"p={p_value} | "
                f"text_len={len(text)}"
            )
        
        logger.info(f"총 {len(impact_scores)}개 논문의 영향 점수 생성 (데이터 완전성 무관)")
        return impact_scores
    
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
        
        prompt = f"""당신은 노화 의학과 피부과학 전문가입니다.
사용자의 생활습관 데이터와 의학 논문의 근거를 기반으로 **{user_data.target_years}년 후 얼굴의 시각적 변화**를 상세히 묘사해야 합니다.

## 핵심 원칙 (개선 버전)

**데이터 분석 우선순위:**
1순위: effect_value 수치가 있다면 해당 수치에 비례하여 묘사
2순위: 수치가 없다면 text 필드에 포함된 형용사(강력한, 유의미한, 경미한 등)를 분석하여 강도 결정
3순위: p_value가 0.05 미만이거나 evidence_level이 Level 1, 2인 정보는 묘사에 적극 반영
       신뢰도가 낮은 정보는 '잠재적 변화'로 완화하여 기술

**신뢰도 평가:**
- Level 1 (메타분석): p-value 없어도 가장 높은 신뢰도, 적극 반영
- Level 2 (RCT/코호트): 높은 신뢰도, 주요 근거로 사용
- Level 3-4: 중간~낮은 신뢰도, 보조적 정보로 활용

**데이터 불완전성 대응:**
- 정량적 수치가 없어도 text 필드의 정성적 내용을 LLM이 해석하여 활용
- 근거 등급(evidence_level)을 신뢰하여 메타분석 논문은 그 자체로 높은 가치 인정
- 특정 필드가 유실(None/Null)되어도 text 필드를 분석해서 로직 유지

## 사용자 정보
{user_summary}

## 의학 논문 근거 및 시각적 강도 (개선 버전)
{evidence_context}

## 시각적 영향 강도 요약
{intensity_summary}

## 요청사항
위 정보를 바탕으로 다음 두 가지를 생성하세요:

### 1. 노화 영향 분석 리포트
각 생활습관 요인이 피부 노화에 미치는 영향을 논문 근거와 함께 분석하세요.
- effect_value, p-value 등 정량적 수치가 있으면 **반드시** 인용
- 수치가 없어도 text 필드의 형용사("강력한", "유의미한" 등)를 해석하여 영향 강도 설명
- 각 요인의 시각적 영향 강도 점수 포함
- 증거 수준(evidence_level) 명시
- Level 1, 2 논문은 높은 신뢰도로 적극 반영, Level 3-4는 보조적으로 활용

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
        
        prompt = f"""당신은 사진 편집 전문가입니다.
한글로 작성된 피부 노화 묘사를 **구체적이고 상세한 영문 사진 설명**으로 변환하세요.

## 핵심 원칙

### 상세도:
- 정량적 수치를 최대한 포함 (깊이mm, 길이cm, 변화율% 등)
- 부위별 구체적 특징 명시
- 의학적으로 정확한 용어 사용

### 표현 규칙:
✅ 사용 가능: natural, visible, noticeable, prominent, characteristic, distinct, clear
✅ 수치 표현: mm, cm, % 등 구체적 측정치
✅ 중립적 설명: changes, variations, characteristics, features

❌ 금지 단어: premature, severe, extreme, dramatic, significant, tired, stressed, damaged, ugly
❌ 부정적 감정: 피곤한, 지친, 손상된 등의 표현

**예시 변환:**
- "심각한 주름" → "prominent crow's feet lines (1.8mm depth)"
- "처진 피부" → "visible changes in skin contour"
- "칙칙한 피부톤" → "skin tone variations (15% darker)"

## 사용자 정보
- 현재 나이: {user_data.age}세
- 예측 나이: **{future_age}세**
- 성별: {gender_en}
- 인종: Asian
- 피부 타입: {user_data.skin_type or 'combination'}

## 시각적 묘사 (한글) - 상세 정보 포함
{visual_description}

## 출력 지시
위 한글 묘사를 바탕으로 **구체적이고 상세한 영문 프롬프트**를 작성하세요.

### 출력 형식:
Professional portrait photograph of a {future_age}-year-old {gender_en} Asian person with {user_data.skin_type or 'combination'} skin. [구체적인 부위별 노화 특징을 수치와 함께 상세히 나열]. Natural studio lighting, front-facing view, high-resolution photography.

### 필수 포함 사항:
1. **눈가 주변 (Periorbital):**
   - Crow's feet lines: 깊이(mm), 길이(cm), 개수
   - Under-eye area: 색상 변화, 다크서클 정도
   - Eyelid changes: 처짐 정도

2. **이마 (Forehead):**
   - Horizontal lines: 개수, 깊이(mm)
   - Vertical frown lines: 깊이(mm)

3. **볼/광대 (Cheeks):**
   - Skin tone: 변화율(%)
   - Pigmentation: 반점 크기(mm), 분포 면적(%)
   - Pore size: 확대 정도(%), 모양 변화
   - Volume changes: 탄력 손실 정도

4. **입가/턱선 (Perioral/Jawline):**
   - Nasolabial folds: 깊이(mm), 길이(cm)
   - Perioral lines: 개수, 위치
   - Jawline: 선명도 변화(%)

5. **전체 피부 (Overall):**
   - Texture: 거칠기 변화
   - Hydration: 건조 정도
   - Radiance: 광택 변화(%)

### 스타일 키워드 (선택적 포함):
- High-resolution photography
- Professional portrait
- Natural studio lighting
- Front-facing view
- Sharp focus on facial details

### 중요: 
- 한글 묘사의 **모든 수치와 정량적 데이터**를 영문으로 정확히 변환
- 부정적 감정 표현 제거 ("tired", "stressed" 등 금지)
- 극단적 형용사 제거 ("severe", "dramatic" 등 금지)
- 중립적이고 객관적인 관찰 표현 사용

**오직 최종 영문 프롬프트만 출력하세요. 설명이나 주석 없이.**"""

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
            
            forbidden_words = ['premature', 'severe', 'extreme', 'dramatic', 'significant', 'damaged', 'ugly', 'tired', 'stressed']
            found_forbidden = [word for word in forbidden_words if word in imagen_prompt.lower()]
            if found_forbidden:
                logger.warning(f"경고: 극단적 표현 발견 - {found_forbidden}. RAI 정책 위반 가능성 있음")
                logger.warning(f"권장: 프롬프트에서 해당 단어를 중립적 표현으로 교체하세요")
            
            logger.info(f" Imagen 3 최적화 프롬프트 생성 성공\n{imagen_prompt}")
            
            return imagen_prompt
            
        except Exception as e:
            logger.error(f"Imagen 프롬프트 생성 실패: {e}")
            raise
    
    def generate_aging_face_image(
        self,
        base_image_path: str,
        imagen_prompt: str,
        visual_description: str = "",
        output_path: str = "output_aging_prediction.png",
        model_name: str = "imagen-4.0-generate-001",
        edit_mode: str = "product-image"  # 기본값 변경: inpainting-insert → product-image
    ) -> str:
        """Step 5: 사용자 얼굴 사진을 기반으로 노화된 얼굴 이미지 생성 (Image-to-Image)
        
        Args:
            base_image_path: 사용자가 업로드한 현재 얼굴 사진 경로
            imagen_prompt: Step 4에서 정제된 노화 효과 영문 프롬프트
            visual_description: Step 3의 상세한 한글 묘사 (선택적)
            output_path: 저장할 파일 경로
            model_name: 사용할 모델 선택
                - Imagen 4.0 계열: "imagen-4.0-generate-001", "imagen-4.0-fast-generate-001", "imagen-4.0-ultra-generate-001"
                - Imagen 3.0 계열: "imagen-3.0-generate-002", "imagen-3.0-generate-001", "imagen-3.0-fast-generate-001"
                - Gemini Image: "gemini-2.5-flash-image" (Nano Banana), "gemini-3-pro-image-preview" (Nano Banana Pro)
            edit_mode: 편집 모드
                - "product-image": 얼굴 사진을 자연스럽게 변환 (기본값, mask 불필요)
                - "inpainting-insert": 얼굴 특징에 노화 효과 삽입 (mask 필요)
                - "inpainting-remove": 특정 영역 제거 (mask 필요)
                - "outpainting": 배경 확장
            
        Returns:
            저장된 노화 이미지 파일 경로
        """
        logger.info(f"Step 5: Image-to-Image 노화 얼굴 생성 시작 (Model: {model_name})")
        logger.info(f"기본 사진: {base_image_path}")
        
        try:
            from vertexai.preview.vision_models import ImageGenerationModel, Image as VertexImage
            import vertexai
            from PIL import Image as PILImage
            
            # Vertex AI 초기화
            project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
            if not project_id:
                raise ValueError(
                    "GOOGLE_CLOUD_PROJECT 환경변수가 설정되지 않았습니다.\n"
                    "Imagen은 Vertex AI를 통해서만 사용 가능합니다.\n"
                    ".env 파일에 GOOGLE_CLOUD_PROJECT=your-project-id 추가하세요.\n\n"
                    "Google Cloud Console: https://console.cloud.google.com/"
                )
            
            vertexai.init(project=project_id, location="us-central1")
            
            # 모델 선택 (Gemini vs Imagen)
            if "gemini" in model_name.lower():
                # Gemini Image 모델 사용 (genai 라이브러리)
                logger.info(f"Gemini Image 모델 사용: {model_name}")
                return self._generate_with_gemini_image(base_image_path, imagen_prompt, output_path, model_name)
            else:
                # Imagen 모델 사용
                logger.info(f"Imagen 모델 사용: {model_name}")
                
                # 기본 사진 로드 - Image.load_from_file() 메서드 사용 (권장 방식)
                logger.info(f"이미지 파일 로딩 중: {base_image_path}")
                base_image = VertexImage.load_from_file(base_image_path)
                logger.info(f"✓ Image.load_from_file() 성공")
                
                # 이미지 객체 검증
                if not hasattr(base_image, '_image_bytes') and not hasattr(base_image, '_gcs_uri'):
                    logger.error("❌ Image 객체가 올바르게 생성되지 않았습니다!")
                    raise ValueError("Image 객체에 image_bytes 또는 gcs_uri가 없습니다.")
                
                logger.info(f"  - Image 객체 검증 완료: bytes={hasattr(base_image, '_image_bytes')}, gcs={hasattr(base_image, '_gcs_uri')}")
                
                # Imagen 모델 로드
                logger.info(f"Imagen 모델 로딩 중: {model_name}")
                imagen_model = ImageGenerationModel.from_pretrained(model_name)
                logger.info(f"✓ Imagen 모델 로드 성공")
                
                # edit_mode 검증: inpainting-insert는 mask 필요, product-image는 mask 불필요
                if edit_mode in ["inpainting-insert", "inpainting-remove"] and not hasattr(self, 'mask_image'):
                    logger.warning(f"⚠️  {edit_mode} 모드는 mask가 필요하지만 제공되지 않았습니다.")
                    logger.warning(f"⚠️  자동으로 'product-image' 모드로 변경합니다.")
                    edit_mode = "product-image"
                
                logger.info(f"✓ edit_mode 확정: {edit_mode}")
                
                # 프롬프트 최적화: 자연스러운 노화 특징 강조 (RAI 정책 준수)
                # visual_description에서 추출한 상세한 수치를 포함하되, 중립적 표현 사용
                if visual_description:
                    # 자연스러운 노화 프로세스 강조 (중립적 프레임)
                    enhanced_prompt = f"A face showing natural aging characteristics: {imagen_prompt}. High quality photograph with natural skin texture and realistic lighting."
                else:
                    # visual_description이 없어도 Imagen 프롬프트 자체에 상세 정보가 있음
                    enhanced_prompt = f"A face with visible aging features: {imagen_prompt}. High quality photograph with natural skin texture and realistic lighting."
                
                # 프롬프트 길이 체크 (참고용)
                if len(enhanced_prompt) > 500:
                    logger.warning(f"⚠️  프롬프트가 길지만 상세한 노화 특징 전달을 위해 유지합니다 ({len(enhanced_prompt)} chars)")
                
                logger.info(f"프롬프트 (최종): {enhanced_prompt[:200]}...")
                
                # Image-to-Image 편집 (노화 효과 적용)
                # base_image 존재 여부 최종 확인
                if base_image is None:
                    raise ValueError("❌ base_image가 None입니다! 이미지 로딩에 실패했습니다.")
                
                logger.info(f"✓ edit_image() 호출 준비 완료")
                logger.info(f"  - base_image: {base_image} (타입: {type(base_image).__name__})")
                logger.info(f"  - edit_mode: {edit_mode}")
                logger.info(f"  - prompt 길이: {len(enhanced_prompt)} chars")
                logger.info(f"  - number_of_images: 1")
                
                # 모든 파라미터를 명시적으로 키워드 인자로 전달
                images = imagen_model.edit_image(
                    prompt=enhanced_prompt,
                    base_image=base_image,  # 명시적으로 키워드 인자로 전달
                    edit_mode=edit_mode,
                    number_of_images=1,
                    safety_filter_level="block_some",
                    person_generation="allow_adult",
                )
                
                logger.info(f"✓ edit_image() 호출 완료 - 응답 수신됨")
                
                # 첫 번째 이미지 저장
                if images and len(images.images) > 0:
                    result_image = images.images[0]
                    result_image.save(location=output_path, include_generation_parameters=False)
                    
                    logger.info(f"✅ 노화 얼굴 이미지 생성 성공: {output_path}")
                    
                    return output_path
                else:
                    raise ValueError("이미지가 생성되지 않았습니다.")
                
        except ImportError as e:
            error_msg = (
                f"Vertex AI SDK가 설치되지 않았습니다: {e}\n"
                "설치 명령: pip install google-cloud-aiplatform\n\n"
                "또는 다음 방법으로 수동 생성하세요:\n"
                "1. Vertex AI Console: https://console.cloud.google.com/vertex-ai/generative/vision\n"
                "2. Google AI Studio: https://aistudio.google.com/app/prompts/new_chat\n"
                f"\n기본 사진: {base_image_path}\n"
                f"프롬프트: {imagen_prompt}"
            )
            logger.error(error_msg)
            raise ImportError(error_msg)
            
        except Exception as e:
            logger.error(f"노화 얼굴 이미지 생성 실패: {e}")
            logger.error(f"오류 세부 정보: {type(e).__name__}")
            
            # 대체 방법 안내
            logger.info("\n=== 대체 이미지 생성 방법 ===")
            logger.info("1. Vertex AI Console: https://console.cloud.google.com/vertex-ai/generative/vision")
            logger.info("2. Google AI Studio: https://aistudio.google.com/")
            logger.info(f"\n기본 사진을 업로드하고 프롬프트를 입력하세요:\n{imagen_prompt}")
            raise
    
    def _generate_with_gemini_image(
        self,
        base_image_path: str,
        prompt: str,
        output_path: str,
        model_name: str
    ) -> str:
        """Gemini Image 모델로 노화 얼굴 생성 (대체 방식)"""
        logger.info(f"Gemini Image 모델 사용: {model_name}")
        
        try:
            from PIL import Image as PILImage
            
            # Gemini 모델 초기화
            gemini_model = genai.GenerativeModel(model_name)
            
            # 이미지 로드
            pil_image = PILImage.open(base_image_path)
            
            # 프롬프트 최적화
            enhanced_prompt = f"Transform this person's face to show these aging effects: {prompt}. Keep their identity recognizable."
            
            # Gemini로 이미지 분석 및 새 이미지 요청
            response = gemini_model.generate_content([
                enhanced_prompt,
                pil_image
            ])
            
            # 주의: Gemini는 이미지를 직접 생성하지 않고 설명만 제공하므로
            # 실제로는 Imagen을 사용해야 합니다
            logger.warning("Gemini Image 모델은 현재 이미지 편집을 직접 지원하지 않습니다.")
            logger.warning("Imagen 4.0 모델을 사용하는 것을 권장합니다.")
            
            raise NotImplementedError(
                "Gemini Image 모델은 현재 이미지 편집을 지원하지 않습니다. "
                "model_name을 'imagen-4.0-generate-001' 등 Imagen 모델로 변경하세요."
            )
            
        except Exception as e:
            logger.error(f"Gemini Image 모델 사용 실패: {e}")
            raise
            
            # 대체 방법 안내
            logger.info("\n=== 대체 이미지 생성 방법 ===")
            logger.info("1. Google AI Studio: https://aistudio.google.com/app/prompts/new_chat")
            logger.info("2. Vertex AI Console: https://console.cloud.google.com/vertex-ai/generative/vision")
            logger.info(f"\n생성된 프롬프트를 복사하여 사용하세요:\n{imagen_prompt}")
            raise
    
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
        논문 근거를 시각적 강도와 함께 포맷팅 (개선 버전)
        
        데이터 불완전성에 관계없이 모든 정보를 활용
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
            
            # 시각적 강도 정보 구성 (개선 버전)
            intensity_info = ""
            if impact_score:
                intensity_value = impact_score.calculate_visual_intensity()
                intensity_desc = impact_score.get_intensity_descriptor()
                confidence = impact_score.get_confidence_level()
                
                intensity_info = f"\n- **시각적 영향 강도**: {intensity_value:.1f}/10 ({intensity_desc})"
                intensity_info += f"\n- **신뢰도**: {confidence}"
                
                # effect_value가 있으면 표시 (1순위)
                if impact_score.effect_value is not None:
                    intensity_info += f"\n- **효과 크기(Effect Size)**: {impact_score.effect_value:.2f}"
                
                # p_value가 있으면 표시 (2순위)
                if impact_score.p_value is not None:
                    intensity_info += f"\n- **p-value**: {impact_score.p_value}"
                
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
            
            summary = f"{i}. **{score.factor_name}**: {intensity:.1f}/10 ({descriptor})"
            
            # 데이터 출처 표시
            data_sources = []
            if score.effect_value is not None:
                data_sources.append(f"Effect={score.effect_value:.2f}")
            if score.p_value is not None:
                data_sources.append(f"p={score.p_value}")
            if score.evidence_level:
                data_sources.append(f"Level {score.evidence_level}")
            
            if data_sources:
                summary += f" | {' | '.join(data_sources)}"
            
            summary += f" | {confidence}"
            
            summary_parts.append(summary)
        
        return "\n".join(summary_parts)
    
    def _parse_llm_response(self, response_text: str) -> tuple:
        """LLM 응답을 리포트와 시각적 묘사로 분리"""
        markers = [
            "## 2. 시각적 묘사",
            "## 2. 부위별 상세 시각적 묘사",
            "## 2. Visual Description",
            "## 시각적 묘사",
            "## Visual Description",
            "2. 시각적 묘사",
            "시각적 묘사:"
        ]
        
        split_index = -1
        for marker in markers:
            if marker in response_text:
                split_index = response_text.index(marker)
                break
        
        if split_index != -1:
            report = response_text[:split_index].strip()
            visual_description = response_text[split_index:].strip()
        else:
            logger.warning("시각적 묘사를 분리할 수 없습니다. 전체를 리포트로 사용합니다.")
            report = response_text
            visual_description = "시각적 묘사를 추출할 수 없습니다."
        
        return report, visual_description


def generate_aging_image_prompt_pipeline(
    user_data: UserLifestyleData,
    base_image_path: Optional[str] = None,
    generate_image: bool = True,
    output_image_path: str = "output_aging_prediction.png",
    model_name: str = "imagen-4.0-generate-001"
) -> Dict:
    """전체 파이프라인 (고도화): 사용자 데이터 → RAG 검색 → 논문 수치 분석 → 부위별 묘사 → Imagen 3 프롬프트 → Image-to-Image 노화 얼굴 생성
    
    Args:
        user_data: 사용자 생활습관 데이터
        base_image_path: 사용자가 업로드한 현재 얼굴 사진 경로 (필수!)
        generate_image: 이미지를 실제로 생성할지 여부 (False일 경우 프롬프트까지만 생성)
        output_image_path: 생성된 이미지 저장 경로
        model_name: 사용할 모델 (Imagen 4.0, 3.0, Gemini Image 등)
            - 추천: "imagen-4.0-generate-001" (최신 버전)
            - 빠른 속도: "imagen-4.0-fast-generate-001"
            - 최고 품질: "imagen-4.0-ultra-generate-001"
        
    Returns:
        파이프라인 결과 (리포트, 시각적 묘사, 프롬프트, 이미지 경로 등)
    """
    logger.info("=== 노화 이미지 생성 파이프라인 (고도화) 시작 ===")
    logger.info(f"사용 모델: {model_name}")
    
    visualizer = BioStreamVisualizer()
    
    # Step 1-2: 검색 쿼리 생성 및 RAG 검색
    queries = visualizer.generate_search_queries(user_data)
    evidence_results = visualizer.search_evidence(queries)
    
    # Step 3: 노화 영향 평가 및 시각적 묘사 생성
    step3_result = visualizer.generate_visual_description(user_data, evidence_results)
    logger.info("Step 3 완료: 리포트 및 부위별 시각적 묘사 생성 성공")
    
    # Step 4: Imagen 3 최적화 프롬프트 변환
    imagen_prompt = visualizer.refine_imagen_prompt(user_data, step3_result['visual_description'])
    logger.info("Step 4 완료: Imagen 3 최적화 프롬프트 변환 성공")
    
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
                    output_path=output_image_path,
                    model_name=model_name
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
        'image_path': image_path,  # 생성된 노화 얼굴 이미지 파일 경로
        'base_image_path': base_image_path,  # 원본 사진 경로
        'model_used': model_name,  # 사용된 모델
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
    
    try:
        print("\n" + "="*80)
        print("BioStream 노화 이미지 생성 파이프라인 테스트 (고도화 버전)")
        print("Image-to-Image 방식: 기존 얼굴 사진 → 노화된 얼굴 생성")
        print("="*80)
        
        # 테스트용 샘플 얼굴 사진 경로
        sample_face_image = "sample_face.jpg"
        
        # 파일 존재 여부 확인
        import os
        if os.path.exists(sample_face_image):
            print(f"\n[확인] 기본 얼굴 사진: {sample_face_image}")
            use_image = True
        else:
            print(f"\n[경고] 샘플 얼굴 사진 없음 ({sample_face_image})")
            print("\n[해결방법 1] 실제 얼굴 사진을 추가하세요:")
            print(f"  - 본인 셀카를 ai_service/{sample_face_image}로 저장")
            print(f"  - 또는 무료 스톡 이미지 다운로드:")
            print(f"    https://unsplash.com/s/photos/face-portrait")
            print(f"    https://www.pexels.com/search/portrait/")
            print("\n[해결방법 2] 테스트용 더미 이미지 생성:")
            
            # 더미 이미지 생성 시도
            try:
                from PIL import Image, ImageDraw, ImageFont
                print("  - 512x512 테스트 이미지 생성 중...")
                
                # 간단한 얼굴 모양의 더미 이미지 생성
                dummy_img = Image.new('RGB', (512, 512), color=(240, 220, 200))
                draw = ImageDraw.Draw(dummy_img)
                
                # 얼굴 윤곽
                draw.ellipse([100, 80, 412, 450], fill=(255, 230, 210), outline=(200, 170, 150))
                
                # 눈
                draw.ellipse([180, 200, 220, 240], fill=(100, 80, 70))
                draw.ellipse([292, 200, 332, 240], fill=(100, 80, 70))
                
                # 코
                draw.line([(256, 240), (256, 310)], fill=(180, 150, 130), width=3)
                
                # 입
                draw.arc([206, 330, 306, 380], 0, 180, fill=(180, 100, 100), width=3)
                
                dummy_img.save(sample_face_image)
                print(f"  ✓ 테스트 이미지 생성 완료: {sample_face_image}")
                print("  (실제 사용 시에는 실제 얼굴 사진으로 교체하세요!)")
                use_image = True
                
            except Exception as e:
                print(f"  ✗ 테스트 이미지 생성 실패: {e}")
                print("\n[결과] 프롬프트만 생성합니다.")
                sample_face_image = None
                use_image = False
        
        # 테스트할 모델들
        test_models = [
            "imagen-4.0-generate-001",  # 최신 Imagen 4.0
            # "imagen-4.0-fast-generate-001",  # 빠른 버전
            # "imagen-3.0-generate-002",  # Imagen 3.0
        ]
        
        print(f"\n[테스트] 사용 모델: {test_models[0]}")
        
        result = generate_aging_image_prompt_pipeline(
            user_data=sample_user,
            base_image_path=sample_face_image,
            generate_image=use_image,
            model_name=test_models[0]
        )
        
        print("\n" + "="*80)
        print("[결과] 파이프라인 결과 요약")
        print("="*80)
        
        print(f"\n[완료] 사용된 검색 쿼리 ({len(result['queries_used'])}개):")
        for i, q in enumerate(result['queries_used'], 1):
            print(f"  {i}. {q}")
        
        print(f"\n[완료] 검색된 논문: {result['evidence_count']}개")
        
        # 이미지 생성 결과
        if result['image_path']:
            print(f"\n[완료] 생성된 이미지: {result['image_path']}")
        else:
            print("\n[알림] 이미지 생성 실패 - 프롬프트만 생성됨")
        
        print("\n" + "-"*80)
        print("[분석] 시각적 영향 강도 점수")
        print("-"*80)
        # Windows 콘솔 인코딩 에러 방지
        try:
            print(result['impact_scores'])
        except UnicodeEncodeError:
            print(result['impact_scores'].encode('cp949', errors='replace').decode('cp949'))
        
        print("\n" + "-"*80)
        print("[리포트] 1. 노화 영향 분석 리포트 (의학적 근거)")
        print("-"*80)
        try:
            print(result['report'])
        except UnicodeEncodeError:
            print(result['report'].encode('cp949', errors='replace').decode('cp949'))
        
        print("\n" + "-"*80)
        print("[묘사] 2. 부위별 상세 시각적 묘사 (한글)")
        print("-"*80)
        try:
            print(result['visual_description'])
        except UnicodeEncodeError:
            print(result['visual_description'].encode('cp949', errors='replace').decode('cp949'))
        
        print("\n" + "-"*80)
        print("[프롬프트] 3. Imagen 3 최적화 프롬프트 (영문)")
        print("-"*80)
        try:
            print(result['imagen_prompt'])
        except UnicodeEncodeError:
            print(result['imagen_prompt'].encode('cp949', errors='replace').decode('cp949'))
        
        print("\n" + "="*80)
        print("[완료] 테스트 완료!")
        print("="*80)
        
        if not result['image_path']:
            print("\n[안내] 이미지 수동 생성 방법:")
            print("1. Google AI Studio: https://aistudio.google.com/app/prompts/new_chat")
            print("2. Vertex AI Console: https://console.cloud.google.com/vertex-ai/generative/vision")
            print("3. 위 Imagen 프롬프트를 복사하여 붙여넣기")
        
        imagen_prompt = result['imagen_prompt'].lower()
        quality_checks = {
            '8k resolution': '8k' in imagen_prompt or 'ultra' in imagen_prompt,
            'Hyper-realistic': 'hyper' in imagen_prompt or 'realistic' in imagen_prompt,
            'Medical-grade': 'medical' in imagen_prompt,
            'Specific age': str(sample_user.age + sample_user.target_years) in result['imagen_prompt'],
            'Asian mentioned': 'asian' in imagen_prompt,
            'No abstract words': not any(word in imagen_prompt for word in ['old', 'aged', 'elderly'])
        }
        
        print("\n" + "-"*80)
        print("[검증] 프롬프트 품질 검증")
        print("-"*80)
        for check, passed in quality_checks.items():
            status = "[OK]" if passed else "[주의]"
            print(f"  {status} {check}: {'통과' if passed else '미흡'}")
        
    except Exception as e:
        logger.error(f"[실패] 테스트 실패: {e}")
        import traceback
        traceback.print_exc()
        raise
