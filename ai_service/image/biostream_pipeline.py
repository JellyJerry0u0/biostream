# ai_service/biostream_pipeline.py
"""
BioStream AI 노화 시뮬레이터 - 통합 파이프라인
RAG(논문 근거) → Gemini 분석 → Replicate SDXL 이미지 생성을 다이렉트로 연결
"""

import os
import sys
import logging
import base64
import replicate
from dotenv import load_dotenv
from pathlib import Path
from typing import Dict, Any, Optional
import google.generativeai as genai
from qdrant_client import QdrantClient

# 상위 디렉토리(ai_service)를 모듈 경로에 추가
current_dir = Path(__file__).parent
parent_dir = current_dir.parent
sys.path.insert(0, str(parent_dir))

from core.embedder import BioEmbedder

# 환경 변수 로드
load_dotenv()

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class BioStreamPipeline:
    """
    BioStream AI 노화 시뮬레이터 통합 파이프라인
    """

    def __init__(self):
        """파이프라인 초기화 및 API 설정"""
        # API 키 확인
        self.google_api_key = os.getenv("GOOGLE_API_KEY")
        self.replicate_api_token = os.getenv("REPLICATE_API_TOKEN")
        
        if not self.google_api_key:
            raise ValueError("GOOGLE_API_KEY가 설정되지 않았습니다.")
        if not self.replicate_api_token:
            raise ValueError("REPLICATE_API_TOKEN이 설정되지 않았습니다.")
        
        # Gemini 설정
        genai.configure(api_key=self.google_api_key)
        
        # 사용 가능한 모델 자동 선택
        model_name = self._select_available_model()
        self.gemini_model = genai.GenerativeModel(model_name)
        logger.info(f"Gemini 모델 초기화: {model_name}")
        
        # Replicate 설정
        os.environ["REPLICATE_API_TOKEN"] = self.replicate_api_token
        
        # RAG 컴포넌트 설정
        self.embedder = BioEmbedder()
        self.qdrant_client = QdrantClient(os.getenv("QDRANT_URL", "http://localhost:6333"))
        self.collection_name = os.getenv("COLLECTION_NAME", "biostream_v1")
        
        logger.info("BioStream 파이프라인 초기화 완료")

    def _select_available_model(self) -> str:
        """사용 가능한 Gemini 모델 자동 선택"""
        try:
            # 선호하는 모델 순서 (flash가 가장 가볍고 빠름)
            preferred_models = [
                'gemini-1.5-flash',
                'gemini-1.5-flash-latest',
                'gemini-flash',
                'gemini-1.5-pro',
                'gemini-1.5-pro-latest',
                'gemini-pro'
            ]
            
            # 사용 가능한 모델 목록 가져오기
            available_models = []
            for model in genai.list_models():
                if 'generateContent' in model.supported_generation_methods:
                    # 'models/' 접두사 제거
                    model_name = model.name.replace('models/', '')
                    available_models.append(model_name)
            
            logger.info(f"사용 가능한 모델: {available_models[:3]}...")
            
            # 선호 모델 중 사용 가능한 것 선택
            for preferred in preferred_models:
                for available in available_models:
                    if preferred == available or preferred in available:
                        return available
            
            # 선호 모델이 없으면 첫 번째 사용 가능한 모델
            if available_models:
                logger.warning(f"선호 모델 없음. {available_models[0]} 사용")
                return available_models[0]
            
            # 모델을 찾을 수 없으면 에러
            raise ValueError("사용 가능한 Gemini 모델을 찾을 수 없습니다.")
            
        except Exception as e:
            logger.error(f"모델 선택 실패: {e}")
            # fallback
            logger.warning("기본 모델 gemini-pro 사용 시도")
            return 'gemini-pro'

    def run(self, user_data: Dict[str, Any], image_path: str) -> Dict[str, Any]:
        """
        전체 파이프라인 실행
        
        Args:
            user_data: 사용자 데이터 (나이, 성별, 생활습관 등)
            image_path: 사용자 사진 경로
            
        Returns:
            dict: {
                'image_url': 생성된 노화 이미지 URL,
                'korean_report': 한글 분석 리포트,
                'evidence': 논문 근거 리스트
            }
        """
        try:
            logger.info("=" * 60)
            logger.info("BioStream 파이프라인 시작")
            logger.info("=" * 60)
            
            # Step 1: RAG 검색 - 논문 근거 수집
            logger.info("\n[Step 1] RAG 검색 시작")
            evidence = self.search_evidence(user_data)
            logger.info(f"논문 근거 {len(evidence)}개 수집 완료")
            
            # Step 2: Gemini 통합 분석
            logger.info("\n[Step 2] Gemini 분석 시작")
            analysis_result = self.analyze_with_gemini(user_data, evidence)
            korean_report = analysis_result['korean_report']
            english_prompt = analysis_result['english_prompt']
            
            logger.info("Gemini 분석 완료")
            logger.info(f"영문 프롬프트: {english_prompt[:100]}...")
            
            # Step 3: Replicate SDXL 이미지 생성
            logger.info("\n[Step 3] Replicate SDXL 이미지 생성 시작")
            
            # 동적 파라미터 계산 (target_years 기반)
            target_years = user_data.get('target_years', 10)
            dynamic_strength = self._calculate_dynamic_strength(target_years)
            dynamic_guidance = self._calculate_dynamic_guidance(target_years)
            dynamic_noise_frac = self._calculate_dynamic_noise_frac(target_years)
            
            logger.info(f"동적 파라미터 계산 완료:")
            logger.info(f"  - Target Years: {target_years}년")
            logger.info(f"  - Prompt Strength: {dynamic_strength}")
            logger.info(f"  - Guidance Scale: {dynamic_guidance}")
            logger.info(f"  - High Noise Frac: {dynamic_noise_frac}")
            
            image_url, local_path = self.generate_image_with_sdxl(
                image_path, 
                english_prompt,
                prompt_strength=dynamic_strength,
                guidance_scale=dynamic_guidance,
                high_noise_frac=dynamic_noise_frac
            )
            logger.info(f"이미지 생성 완료: {image_url}")
            if local_path:
                logger.info(f"로컬 저장 완료: {local_path}")
            
            # 최종 결과 반환
            result = {
                'image_url': image_url,
                'local_image_path': local_path,
                'korean_report': korean_report,
                'evidence': evidence,
                'raw_prompt': english_prompt
            }
            
            logger.info("\n" + "=" * 60)
            logger.info("BioStream 파이프라인 완료!")
            logger.info("=" * 60)
            
            return result
            
        except Exception as e:
            logger.error(f"파이프라인 실행 중 오류 발생: {str(e)}")
            raise

    def search_evidence(self, user_data: Dict[str, Any]) -> list:
        """
        Step 1: 사용자 데이터 기반 RAG 검색
        
        Args:
            user_data: 사용자 정보 딕셔너리
            
        Returns:
            list: 논문 근거 리스트
        """
        try:
            # 검색 쿼리 생성
            query = self._create_search_query(user_data)
            logger.info(f"검색 쿼리: {query}")
            
            # 쿼리 임베딩
            query_vector = self.embedder.embed_text(query)
            
            # Qdrant 검색 (상위 5개)
            search_results = self.qdrant_client.query_points(
                collection_name=self.collection_name,
                query=query_vector,
                limit=5,
                with_payload=True,
                with_vectors=False
            ).points
            
            # 결과 포맷팅
            evidence_list = []
            for i, result in enumerate(search_results, 1):
                evidence = {
                    'rank': i,
                    'score': round(result.score, 4),
                    'text': result.payload.get('text', ''),
                    'paper_id': result.payload.get('paper_id', 'N/A'),
                    'evidence_level': result.payload.get('evidence_level', 'N/A'),
                    'study_type': result.payload.get('study_type', 'N/A'),
                }
                evidence_list.append(evidence)
                
                logger.info(f"  [{i}] 점수: {evidence['score']:.4f} | 근거 수준: {evidence['evidence_level']}")
            
            return evidence_list
            
        except Exception as e:
            logger.error(f"RAG 검색 중 오류: {str(e)}")
            raise

    def _create_search_query(self, user_data: Dict[str, Any]) -> str:
        """사용자 데이터로부터 검색 쿼리 생성"""
        age = user_data.get('age', 30)
        gender = user_data.get('gender', '남성')
        
        # 생활습관 정보 추출
        lifestyle_factors = []
        if user_data.get('smoking'):
            lifestyle_factors.append('흡연')
        if user_data.get('drinking'):
            lifestyle_factors.append('음주')
        if user_data.get('stress_level', 0) > 7:
            lifestyle_factors.append('고강도 스트레스')
        if user_data.get('sleep_hours', 7) < 6:
            lifestyle_factors.append('수면 부족')
        if user_data.get('exercise_frequency', 0) < 2:
            lifestyle_factors.append('운동 부족')
        
        lifestyle_str = ', '.join(lifestyle_factors) if lifestyle_factors else '일반적인 생활습관'
        
        # 검색 쿼리 생성
        query = f"{age}세 {gender}의 피부 노화, {lifestyle_str}의 영향, 주름, 피부 처짐, 색소 침착"
        
        return query

    def analyze_with_gemini(self, user_data: Dict[str, Any], evidence: list) -> Dict[str, str]:
        """
        Step 2: Gemini를 통한 통합 분석
        
        Args:
            user_data: 사용자 정보
            evidence: 논문 근거 리스트
            
        Returns:
            dict: {
                'korean_report': 한글 분석 리포트,
                'english_prompt': SDXL용 영문 프롬프트
            }
        """
        try:
            # 프롬프트 작성
            prompt = self._create_gemini_prompt(user_data, evidence)
            
            # Gemini 호출
            response = self.gemini_model.generate_content(prompt)
            response_text = response.text
            
            # 응답 파싱 (한글 리포트와 영문 프롬프트 분리)
            korean_report, english_prompt = self._parse_gemini_response(response_text)
            
            return {
                'korean_report': korean_report,
                'english_prompt': english_prompt
            }
            
        except Exception as e:
            logger.error(f"Gemini 분석 중 오류: {str(e)}")
            raise


    """Gemini용 프롬프트 생성"""
    def _create_gemini_prompt(self, user_data: Dict[str, Any], evidence: list) -> str:
        
        
        # 논문 근거 텍스트 조합
        evidence_text = "\n\n".join([
            f"[논문 {e['rank']}] (근거 수준: {e['evidence_level']}, 유사도: {e['score']})\n{e['text'][:500]}"
            for e in evidence
        ])
        
        # 사용자 데이터 요약
        age = user_data.get('age', 30)
        gender = user_data.get('gender', '남성')
        smoking = "흡연자" if user_data.get('smoking') else "비흡연자"
        drinking = "음주" if user_data.get('drinking') else "비음주"
        stress = user_data.get('stress_level', 5)
        sleep = user_data.get('sleep_hours', 7)
        exercise = user_data.get('exercise_frequency', 3)
        
        prompt = f"""당신은  AI 노화 시뮬레이터이자 노화 수석 분석가(Senior Analyst)이자 이미지 공학자입니다.
                     
                     당신의 임무는 제공된 의학 논문 데이터(Evidence)를 분석하여 사용자의 미래를 과학적으로 예측하고, 이를 바탕으로 SDXL 모델이 생성할 수 있는 가장 '생물학적으로 정확한' 시각적 명세서를 작성하는 것입니다.
                    
                    논문 데이터의 수치(mm, cm, %)를 바탕으로 픽셀의 대비(Contrast), 그림자(Shadow), 텍스처(Texture)를 
**어떻게 표현할지 구체적으로 묘사**해야 합니다
또한 논문의 데이터를 기반으로 얼굴 부위별 노화를 상세 분석하여 **정확한 시각적 표현**하고 묘사해야 합니다.
아래 논문 근거와 사용자 데이터를 기반으로 두 가지 출력을 생성하세요.

##분석 대상 데이터
# 논문 근거(RAG): {evidence_text}
# 사용자 데이터
- 나이: {age}세
- 성별: {gender}
- 흡연: {smoking}
- 음주: {drinking}
- 스트레스 수준: {stress}/10
- 수면 시간: {sleep}시간
- 운동 빈도: 주 {exercise}회

##[지침 1:논문 기반 분석 및 리포트 작성]
1. 논문에 명시된 수치(mm, cm, %)를 바탕으로 사용자의 피부 노화 양상을 분석하세요.
2. 사실적으로 객관적인 톤을 유지하며, 근거 없는 미화나 과장된 공포는 배제하세요.
3. [한글 리포트]에는 다음을 포함합니다:
  - 현재 생활습관이 피부 노화에 미치는 영향 요약
  - 각 생활습관별 노화 기여도 분석
  - 논문 근거 기반 예상 노화 양상 (주름, 탄력, 색소 침착 등)
  - 논문에서 예측하는 부위별 정밀 변화 (주름 깊이 mm, 색소 농도 % 등 시각화 가능한 수치 언급)
  - 과학적 근거에 기반한 개인 맞춤형 예방 솔루션

##[지침 2: SDXL 기술 지침서(영문 프롬프트) 작성]
1. 프롬프트 구조 및 순서 (중요도 순):

[Anchor]: 신원 고정 문구 (맨 앞에 배치)

[Contrast]: 주름의 입체감을 위한 조명 설정

[Aging Details]: 논문 수치 기반의 피부 변화 (직설적 태그)

[Photography Spec]: 실사 품질 고정

2. 세부 작성 규칙:

신원 고정(Identity Lock): "A high-resolution photorealistic portrait of the EXACT SAME PERSON from the input photo"로 시작하십시오. "identical bone structure", "same eye geometry", "original nose bridge"를 명시하여 얼굴 변형(Morphing)을 금지하세요.

수치의 시각화(Visualizing Data): - '2.5mm 주름' → deeply etched crevices with dark micro-shadows

'탄력 20% 감소' → visible skin laxity and softening of the jawline definition

'기미/잡티' → pronounced solar lentigines and mottled hyperpigmentation spots

조명의 활용: 주름이 밋밋하게 보이지 않도록 harsh side-lighting, dramatic Rembrandt lighting을 추가하여 굴곡마다 **그림자(Shadow)**가 지게 하세요.

3. 금지 사항 및 가중치:

순화 표현 절대 금지: aging, wrinkles, sagging, jowls, liver spots, crow's feet를 최대 강도로 사용하세요.

문장 지양, 태그 지향: 미사여구 대신 쉼표로 구분된 강력한 키워드 조합으로 작성하세요.

4. 출력 형식 (엄격 준수): "A photorealistic portrait of the EXACT SAME PERSON from the input photo, preserving identical facial structure. [Age]-year-old mature version. (여기에 부위별 노화 태그 나열), sharp micro-shadows in every wrinkle, weathered leathery skin texture, highly detailed skin pores, cinematic side-lighting, 8k RAW photo, professional DSLR, masterpiece."


## 응답 형식(반드시 준수)

[한글 리포트]
(여기에 한글 리포트 작성, 논문 데이터를 인용한 과학적 분석 내용을 꼼꼼하게 작성)

[영문 프롬프트]
(여기에 영문 프롬프트 작성, 아래의 구조를 엄격히 지켜 출력)
프롬프트 형식:
"Hyper-realistic close-up portrai of the EXACT SAME PERSON from the input photo, now appearing much older with a natural aging process. 
[IDENTITY]: Preserving the original anatomical bone structure, specific eye shape, and nose profile without any morphing. 
[BIOLOGICAL_AGING]: Based on clinical evidence, showing forehead_lines, deep_etched_nasolabial_folds, and pronounced_periorbital_wrinkles .
[SKIN_DETAIL]: Highly detailed weathered skin texture, visible age spots, uneven skin tone, solar lentigines, and micro-shadows in every facial crevice. 
[PHOTOGRAPHY]: 8k resolution, sharp focus on skin imperfections, cinematic side-lighting to accentuate wrinkles, professional DSLR quality, raw photo, masterpiece.
[AGING_TEXTURE]: Deeply etched anatomical facial crevices, heavy nasolabial folds, pronounced static crow’s feet with sharp micro-shadows. Weathered skin, severe solar elastosis, rough leathery texture, widespread hyper-pigmentation, dark age spots, mottled skin tone. [LIGHTING_DEPTH]: Dramatic Rembrandt lighting, harsh side-lighting to accentuate skin sagging and wrinkle depth, subsurface scattering on skin. [TECHNICAL]: Macro photography, 85mm lens, f/2.8, 8k RAW, visible skin pores, masterpiece, extremely detailed iris, sharp focus on facial imperfections."
"""



        
        return prompt

    def _parse_gemini_response(self, response_text: str) -> tuple[str, str]:
        """Gemini 응답에서 한글 리포트와 영문 프롬프트 분리"""
        try:
            # 구분자로 분리
            if "[영문 프롬프트]" in response_text:
                parts = response_text.split("[영문 프롬프트]")
                korean_part = parts[0].replace("[한글 리포트]", "").strip()
                english_part = parts[1].strip()
            else:
                # 대체 방법: 마지막 영어 문장을 프롬프트로 간주
                lines = response_text.split('\n')
                korean_lines = []
                english_lines = []
                
                for line in lines:
                    # 영어 비율이 높으면 영문 프롬프트로 간주
                    if line.strip() and self._is_mostly_english(line):
                        english_lines.append(line)
                    else:
                        korean_lines.append(line)
                
                korean_part = '\n'.join(korean_lines).strip()
                english_part = ' '.join(english_lines).strip()
            
            return korean_part, english_part
            
        except Exception as e:
            logger.error(f"응답 파싱 중 오류: {str(e)}")
            # 파싱 실패 시 전체를 한글 리포트로, 기본 프롬프트 사용
            default_prompt = "A realistic portrait showing natural aging effects: deep wrinkles, fine lines, age spots, skin sagging. High detail, photorealistic."
            return response_text, default_prompt

    def _is_mostly_english(self, text: str) -> bool:
        """텍스트가 주로 영어인지 판단"""
        if not text:
            return False
        english_chars = sum(1 for c in text if c.isascii() and c.isalpha())
        total_chars = sum(1 for c in text if c.isalpha())
        return total_chars > 0 and (english_chars / total_chars) > 0.7

    def _calculate_dynamic_strength(self, target_years: int) -> float:
        """
        예측 연도에 따른 동적 prompt_strength 계산
        
        Args:
            target_years: 예측 기간 (년)
            
        Returns:
            최적화된 prompt_strength (0.40~0.55)
            
        전략 (Identity 보존 최우선):
            - 단기 (10년 미만): 0.40~0.45 (원본 유지력 극대화)
            - 중기 (10~20년): 0.46~0.50 (안전 영역)
            - 장기 (30년 이상): 0.51~0.55 (뚜렷한 노화, Identity 유지)
        """
        base_strength = 0.48  # 0.48 → 0.43으로 낮춤
        additional_strength = (target_years // 10) * 0.025  # 0.03 → 0.025로 낮춤
        final_strength = min(base_strength + additional_strength, 0.55)  # 0.60 → 0.55로 캡핑
        
        logger.info(f"💡 동적 강도 계산 (Identity 우선): {target_years}년 → {final_strength}")
        return round(final_strength, 2)

    def _calculate_dynamic_guidance(self, target_years: int) -> float:
        """
        예측 연도에 따른 동적 guidance_scale 계산
        
        Args:
            target_years: 예측 기간 (년)
            
        Returns:
            최적화된 guidance_scale (7.5~10.0)
            
        전략:
            - 단기: 7.5 (자연스러운 변화)
            - 장기: 9~10 (프롬프트 충실도 증가로 노화 강조)
        """
        if target_years < 10:
            return 7.5
        elif target_years < 20:
            return 8.0
        elif target_years < 30:
            return 8.5
        else:
            return 9.0

    def _calculate_dynamic_noise_frac(self, target_years: int) -> float:
        """
        예측 연도에 따른 동적 high_noise_frac 계산
        
        Args:
            target_years: 예측 기간 (년)
            
        Returns:
            최적화된 high_noise_frac (0.7~0.8)
            
        전략:
            - 단기: 0.75 (부드러운 피부 질감)
            - 장기: 0.70 (거친 피부 질감, Refiner 30% 사용)
        """
        if target_years < 15:
            return 0.75
        else:
            return 0.70  # Refiner가 더 많은 비중으로 피부 결 정교화

    #Replicate API를 사용한 SDXL 이미지 생성
    def generate_image_with_sdxl(self, image_path: str, prompt: str, 
                                 prompt_strength: float = 0.55,
                                 guidance_scale: float = 7.5,
                                 high_noise_frac: float = 0.8,
                                 negative_prompt: str = None) -> str:
        """
        Step 3: Replicate SDXL을 사용한 이미지 생성 (Image-to-Image)
        
        Args:
            image_path: 입력 이미지 경로
            prompt: 생성 프롬프트
            prompt_strength: 프롬프트 강도 (Denoising Strength)
                - 동적 계산 권장 (target_years 기반)
                - 0.45~0.50: 단기 (10년 미만)
                - 0.52~0.55: 중기 (10~20년, Goldilocks Zone)
                - 0.56~0.60: 장기 (30년 이상)
            guidance_scale: 프롬프트 충실도
                - 7.5~10.0 사이 조절
                - 높을수록 프롬프트 단어에 더 집착
            high_noise_frac: Base/Refiner 비율
                - 0.8: Base 80%, Refiner 20% (부드러운 결)
                - 0.7: Base 70%, Refiner 30% (거친 결, 노화 피부)
            negative_prompt: 부정적 프롬프트 (실사 품질 방해 요소 차단)
            
        Returns:
            tuple: (이미지 URL, 로컬 경로)
        """
        try:
            # 기본 negative_prompt 설정 (Identity 보존 최우선)
            if negative_prompt is None:
                negative_prompt = (
                    # Identity 보존 핵심 (눈, 코, 골격 고정)
                    "changing eye color, different eye color, blue eyes, green eyes, " # 눈 색 변경 차단
                    "altering facial bone structure, changing eye shape, changing nose shape, "
                    "different person, face morphing, facial reconstruction, new face, "
                    "Asian to Caucasian, race change, ethnicity change, "
                    # 노화가 아닌 변형 차단
                    "young, child, baby, teenager, rejuvenation, younger, "
                    "plastic surgery, botox, facelift, "
                    # 실사 품질 방해 요소
                    "cartoon, drawing, anime, illustration, 3d render, painting, "
                    "smooth skin, plastic texture, artificial, digital art, CGI, "
                    "heavy makeup, excessive makeup, filters, "
                    # 얼굴 왜곡
                    "distorted face, deformed, disfigured, mutated, "
                    "blur, blurry, soft focus, low quality"
                )
            
            # prompt_strength 범위 검증 및 경고
            if prompt_strength < 0.5:
                logger.warning(f"⚠️ prompt_strength가 {prompt_strength}로 너무 낮습니다. 노화 효과가 거의 나타나지 않을 수 있습니다.")
            elif prompt_strength >= 0.6:
                logger.warning(f"⚠️ prompt_strength가 {prompt_strength}로 너무 높습니다. Identity가 손실될 수 있습니다.")
            
            # 이미지 파일을 base64로 인코딩
            with open(image_path, 'rb') as image_file:
                image_data = base64.b64encode(image_file.read()).decode('utf-8')
                image_uri = f"data:image/jpeg;base64,{image_data}"
            
            logger.info(f"이미지 로드 완료: {image_path}")
            logger.info(f"📊 SDXL 파라미터:")
            logger.info(f"   - Prompt Strength: {prompt_strength}")
            logger.info(f"   - Guidance Scale: {guidance_scale}")
            logger.info(f"   - High Noise Frac: {high_noise_frac}")
            logger.info(f"   - Negative Prompt: {negative_prompt[:80]}...")
            
            # Replicate SDXL 호출 (동적 파라미터 적용)
            output = replicate.run(
                "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
                input={
                    "image": image_uri,
                    "prompt": prompt,
                    "negative_prompt": negative_prompt,
                    "prompt_strength": prompt_strength,  # 동적 계산됨
                    "num_outputs": 1,
                    "num_inference_steps": 30,
                    "guidance_scale": guidance_scale,  # 동적 계산됨
                    "scheduler": "DPMSolverMultistep",
                    "refine": "expert_ensemble_refiner",
                    "high_noise_frac": high_noise_frac  # 동적 계산됨
                }
            )
            
            # 결과 URL 추출 및 로컬 저장
            if isinstance(output, list) and len(output) > 0:
                image_url = output[0]
            else:
                image_url = str(output)
            
            # 이미지 다운로드 및 로컬 저장
            logger.info(f"이미지 다운로드 중: {image_url}")
            local_path = self._download_image(image_url, image_path)
            if local_path:
                logger.info(f"✅ 이미지 저장 완료: {local_path}")
            else:
                logger.warning("⚠️ 이미지 로컬 저장 실패 (URL은 사용 가능)")
            
            return image_url, local_path
            
        except Exception as e:
            logger.error(f"SDXL 이미지 생성 중 오류: {str(e)}")
            raise

    def _download_image(self, image_url: str, original_path: str) -> str:
        """생성된 이미지를 다운로드하여 로컬에 저장"""
        import requests
        from datetime import datetime
        
        try:
            # 저장 경로 생성 (원본 이미지와 같은 폴더)
            original_file = Path(original_path)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_filename = f"aged_{original_file.stem}_{timestamp}.png"
            output_path = original_file.parent / output_filename
            
            # 이미지 다운로드
            response = requests.get(image_url, timeout=30)
            response.raise_for_status()
            
            # 파일로 저장
            with open(output_path, 'wb') as f:
                f.write(response.content)
            
            return str(output_path)
            
        except Exception as e:
            logger.error(f"이미지 다운로드 실패: {e}")
            return None


def main():
    """테스트 실행"""
    try:
        # 샘플 사용자 데이터
        user_data = {
            'age': 35,
            'gender': '남성',
            'smoking': True,
            'drinking': True,
            'stress_level': 8,
            'sleep_hours': 5,
            'exercise_frequency': 1
        }
        
        # 테스트 이미지 경로 (실제 경로로 변경 필요)
        image_path = "test_image.jpg"
        
        # 파이프라인 실행
        pipeline = BioStreamPipeline()
        result = pipeline.run(user_data, image_path)
        
        # 결과 출력
        print("\n" + "=" * 60)
        print("최종 결과")
        print("=" * 60)
        print(f"\n[생성 이미지]\n{result['image_url']}")
        print(f"\n[한글 리포트]\n{result['korean_report']}")
        print(f"\n[논문 근거 개수]: {len(result['evidence'])}")
        
    except Exception as e:
        logger.error(f"테스트 실행 실패: {str(e)}")


if __name__ == "__main__":
    main()
