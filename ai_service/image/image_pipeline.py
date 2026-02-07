# ai_service/image/image_pipeline.py
"""
BioStream AI 노화 시뮬레이터 - 역할 분리 아키텍처
- Gemini: 무엇을(What) - 순수 팩트만 생성
- Python: 조립(Assemble) - 팩트 + Technical Preset + Identity Anchor
- Replicate: 생성(Generate) - 최종 프롬프트로 이미지 생성
"""

import os
import sys
import logging
import base64
import replicate
from dotenv import load_dotenv
from pathlib import Path
from typing import Dict, Any, Optional, Literal
from datetime import datetime
import google.generativeai as genai
from qdrant_client import QdrantClient
from openai import OpenAI
from google.cloud import aiplatform
from vertexai.preview.vision_models import ImageGenerationModel

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


class ImagePipeline:
    """
    역할 분리 아키텍처 파이프라인
    """
    
    # 고정된 Technical Preset (Python이 관리)
    TECHNICAL_PRESET = """[PHOTOGRAPHY_TECHNICAL]: 8k resolution, professional DSLR camera, 85mm portrait lens, f/2.8 aperture, sharp focus on skin texture, RAW photo quality, unfiltered, no retouching.
[LIGHTING_SETUP]: Harsh cinematic side-lighting to accentuate deep shadows in wrinkles and skin crevices, revealing subsurface scattering and texture depth.
[QUALITY_MARKERS]: masterpiece, photorealistic, hyperrealistic, extremely detailed, brutal realism portrait."""

    # TEXTURE_BOOSTER : 노골적이고 적나라한 질감 표현을 위한 중간 가속기
    TEXTURE_BOOSTER = """[EXPLICIT_TEXTURE_EMPHASIS]: Emphasize raw, unfiltered skin imperfections.
- Visible solar lentigines (age spots) with irregular borders and varying dark pigmentation across cheeks and forehead.
- Pronounced uneven skin tone with visible redness (erythema) and broken capillaries (telangiectasia) on nose and cheeks.
- Deeply etched static wrinkles that cast distinct micro-shadows.
- Significant skin laxity and sagging (ptosis) along the jawline, forming visible jowls.
- Rough, leathery, weathered skin texture with visible enlarged pores and dryness."""

    # 고정된 Identity Anchor - Replicate용 (Python이 관리)
    IDENTITY_ANCHOR = """[IDENTITY_PRESERVATION_CRITICAL]: A photorealistic portrait of THE EXACT SAME PERSON from the input photo. Maintain absolute structural integrity.
- Preserve IDENTICAL bone structure (skull shape, cheekbones, jawline contour, chin definition).
- Preserve IDENTICAL eye shape, eye placement, and iris color.
- Preserve IDENTICAL nose bridge, tip structure, and nostril shape.
- Preserve IDENTICAL mouth width and lip shape.
- The subject must be immediately recognizable as the original individual, only older."""

    # GPT 전용 Identity Lock - 해부학적 서술 강화
    GPT_IDENTITY_LOCK = """[STRICT_IDENTITY_LOCK - DO NOT ALTER]: 
- Maintain the EXACT original facial bone structure and skull shape (zygomatic arch, mandibular angle, mental protuberance).
- Keep the identical eye color, epicanthic fold configuration, and interpupillary distance.
- Preserve the specific nasal bone structure: bridge height, cartilage shape, nostril width from the source.
- Do not change the jawline's skeletal width (bigonial distance) or the chin's bony protrusion.
- CRITICAL: Keep the youth base structure intact, only overlay aging textures additively."""

    # GPT 전용 Negative Prompt - 강화된 금지어
    GPT_NEGATIVE_PROMPT = """Face morphing, changing ethnicity, different bone structure, facial reconstruction, race change,
Asian to Caucasian transformation, Caucasian to Asian transformation, different eye shape, different nose bridge,
altering facial geometry, face swap, identity change, different person,
changing eye color permanently, blue eyes when originally brown, green eyes when originally brown,
young, teenager, child, baby face, rejuvenation, reverse aging, younger appearance,
plastic surgery result, botox effect, facelift appearance, cosmetic reconstruction,
smooth skin like porcelain, artificial texture, CGI skin, 3D render, digital painting,
heavy makeup, beauty filter, instagram filter, face app, smooth filter,
distorted anatomy, deformed face, mutated features, extra limbs, missing features,
blur, blurry, soft focus, low quality, pixelated, low resolution"""

    # Replicate 전용 Negative Prompt
    REPLICATE_NEGATIVE_PROMPT = """changing eye color, different eye color, blue eyes, green eyes, hazel eyes, 
altering facial bone structure, changing eye shape, changing nose shape, different nose,
different person, face morphing, facial reconstruction, new face, face swap,
Asian to Caucasian, race change, ethnicity change, different ethnicity,
young, child, baby, teenager, rejuvenation, younger appearance,
plastic surgery, botox, facelift, cosmetic surgery, blurry
cartoon, drawing, anime, illustration, 3d render, painting, sketch, digital art, CGI,
smooth skin, plastic texture, porcelain skin, artificial, fake,
heavy makeup, excessive makeup, filters, beauty filter, instagram filter,
distorted face, deformed, disfigured, mutated, extra limbs, missing features,
blur, blurry, soft focus, out of focus, low quality, low resolution, pixelated"""

    def __init__(self, image_model: Literal["replicate", "openai", "gemini-imagen", "gemini-flash-imagen", "gemini-2.5-flash-image", "gemini-3-pro-image"] = "replicate"):
        """
        파이프라인 초기화 및 API 설정
        
        Args:
            image_model: 이미지 생성 모델 선택 
                - "replicate": Replicate SDXL
                - "openai": OpenAI gpt-image-1
                - "gemini-imagen": Gemini 3.0 Pro Image Preview (Vertex AI)
                - "gemini-flash-imagen": Gemini 2.5 Flash Image (Vertex AI)
                - "gemini-2.5-flash-image": Gemini 2.5 Flash Image (Gemini API 직접 사용)
                - "gemini-3-pro-image": Gemini 3.0 Pro Image Preview (Gemini API 직접 이미지 생성)
        """
        self.image_model = image_model
        
        # API 키 확인
        self.google_api_key = os.getenv("GOOGLE_API_KEY")
        
        if not self.google_api_key:
            raise ValueError("GOOGLE_API_KEY가 설정되지 않았습니다.")
        
        # 이미지 생성 모델에 따라 API 키 확인 및 초기화
        if image_model == "replicate":
            self.replicate_api_token = os.getenv("REPLICATE_API_TOKEN")
            if not self.replicate_api_token:
                raise ValueError("REPLICATE_API_TOKEN이 설정되지 않았습니다.")
            os.environ["REPLICATE_API_TOKEN"] = self.replicate_api_token
            logger.info("🎨 이미지 생성 모델: Replicate SDXL")
        elif image_model == "openai":
            self.openai_api_key = os.getenv("OPENAI_API_KEY")
            if not self.openai_api_key:
                raise ValueError("OPENAI_API_KEY가 설정되지 않았습니다.")
            self.openai_client = OpenAI(api_key=self.openai_api_key)
            logger.info("🎨 이미지 생성 모델: OpenAI gpt-image-1 (Image Edit)")
        elif image_model == "gemini-2.5-flash-image":
            # Gemini API 직접 사용 (Vertex AI 불필요)
            genai.configure(api_key=self.google_api_key)
            # gemini-2.5-flash-image 모델 초기화
            self.gemini_image_model = genai.GenerativeModel("gemini-2.5-flash-preview-0205")
            logger.info("🎨 이미지 생성 모델: Gemini 2.5 Flash (Gemini API 직접)")
            logger.info("⚠️  실험적 모델입니다. 이미지 생성 기능이 제한적일 수 있습니다.")
        elif image_model == "gemini-3-pro-image":
            # Gemini 3.0 Pro Image Preview (이미지 생성 지원)
            genai.configure(api_key=self.google_api_key)
            self.gemini_image_model = genai.GenerativeModel("gemini-3-pro-image-preview")
            logger.info("🎨 이미지 생성 모델: Gemini 3.0 Pro Image Preview (이미지 생성 지원)")
        elif image_model in ["gemini-imagen", "gemini-flash-imagen"]:
            # Gemini 이미지 생성 모델 (Vertex AI Imagen 3)
            self.gcp_project = os.getenv("GOOGLE_CLOUD_PROJECT")
            self.gcp_location = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")
            
            if not self.gcp_project:
                raise ValueError("GOOGLE_CLOUD_PROJECT가 설정되지 않았습니다. .env 파일에 GCP 프로젝트 ID를 추가하세요.")
            
            # Vertex AI 초기화
            aiplatform.init(project=self.gcp_project, location=self.gcp_location)
            
            # Imagen 모델 선택
            if image_model == "gemini-flash-imagen":
                self.imagen_model = ImageGenerationModel.from_pretrained("imagegeneration@006")  # Imagen 3 Fast
                logger.info(f"🎨 이미지 생성 모델: Vertex AI Imagen 3 Fast (Project: {self.gcp_project})")
            else:
                self.imagen_model = ImageGenerationModel.from_pretrained("imagegeneration@006")  # Imagen 3
                logger.info(f"🎨 이미지 생성 모델: Vertex AI Imagen 3 (Project: {self.gcp_project})")
        else:
            raise ValueError(f"지원하지 않는 이미지 모델: {image_model}")
        
        # Gemini 팩트 생성용 모델 설정 (텍스트 분석용)
        genai.configure(api_key=self.google_api_key)
        model_name = self._select_available_model()
        self.gemini_model = genai.GenerativeModel(model_name)
        logger.info(f"Gemini 모델 초기화: {model_name}")
        
        # RAG 컴포넌트 설정
        self.embedder = BioEmbedder()
        self.qdrant_client = QdrantClient(os.getenv("QDRANT_URL", "http://localhost:6333"))
        self.collection_name = os.getenv("COLLECTION_NAME", "biostream_v1")
        
        logger.info(f"ImagePipeline 초기화 완료 (역할 분리 아키텍처, {image_model} 모드)")

    def _select_available_model(self) -> str:
        """사용 가능한 Gemini 모델 자동 선택"""
        try:
            preferred_models = [
                'gemini-1.5-flash',
                'gemini-1.5-flash-latest',
                'gemini-flash',
                'gemini-1.5-pro',
                'gemini-1.5-pro-latest',
                'gemini-pro'
            ]
            
            available_models = []
            for model in genai.list_models():
                if 'generateContent' in model.supported_generation_methods:
                    model_name = model.name.replace('models/', '')
                    available_models.append(model_name)
            
            logger.info(f"사용 가능한 모델: {available_models[:3]}...")
            
            for preferred in preferred_models:
                for available in available_models:
                    if preferred == available or preferred in available:
                        return available
            
            if available_models:
                logger.warning(f"선호 모델 없음. {available_models[0]} 사용")
                return available_models[0]
            
            raise ValueError("사용 가능한 Gemini 모델을 찾을 수 없습니다.")
            
        except Exception as e:
            logger.error(f"모델 선택 실패: {e}")
            logger.warning("기본 모델 gemini-pro 사용 시도")
            return 'gemini-pro'

    def run(self, user_data: Dict[str, Any], image_path: str) -> Dict[str, Any]:
        """
        전체 파이프라인 실행
        
        Args:
            user_data: 사용자 데이터
            image_path: 사용자 사진 경로
            
        Returns:
            dict: 생성 결과
        """
        try:
            logger.info("=" * 80)
            logger.info("ImagePipeline 시작 (역할 분리 아키텍처)")
            logger.info("=" * 80)
            
            # Step 1: RAG 검색 - 논문 근거 수집
            logger.info("\n[Step 1] RAG 검색")
            evidence = self.search_evidence(user_data)
            logger.info(f"✅ 논문 근거 {len(evidence)}개 수집")
            
            # Step 2: Gemini 분석 - 순수 팩트만 생성 (What)
            logger.info("\n[Step 2] Gemini 팩트 생성 (What)")
            gemini_facts = self.generate_facts_with_gemini(user_data, evidence)
            korean_report = gemini_facts['korean_report']
            aging_facts = gemini_facts['aging_facts']
            
            logger.info(f"✅ Gemini 팩트 생성 완료 (길이: {len(aging_facts)}자)")
            
            # Step 3: Python 조립 - 모델별 프롬프트 분기
            logger.info(f"\n[Step 3] Python 프롬프트 조립 ({self.image_model.upper()}용)")
            
            if self.image_model == "openai":
                # GPT 전용 레이어 구조 프롬프트
                final_prompt = self.assemble_gpt_prompt(aging_facts)
                logger.info(f"✅ GPT 프롬프트 조립 완료 (레이어 구조)")
                logger.info(f"   - SCENE + SUBJECT: 맥락 정의")
                logger.info(f"   - STRICT_IDENTITY_LOCK: {len(self.GPT_IDENTITY_LOCK)}자")
                logger.info(f"   - RAG_BASED_AGING_LAYERS: {len(aging_facts)}자")
                logger.info(f"   - TEXTURE_&_DETAIL + PHOTOGRAPHY: 질감+촬영")
                logger.info(f"   - 최종 프롬프트: {len(final_prompt)}자")
            elif self.image_model in ["gemini-imagen", "gemini-flash-imagen", "gemini-2.5-flash-image", "gemini-3-pro-image"]:
                # Gemini 전용 Visual Anchoring 프롬프트
                final_prompt = self.assemble_gemini_prompt(aging_facts)
                logger.info(f"✅ Gemini 프롬프트 조립 완료 (Visual Anchoring)")
                logger.info(f"   - SYSTEM_INSTRUCTION: 텍스처 리터칭 전문가")
                logger.info(f"   - IDENTITY_LOCK: 픽셀 단위 구조 보존")
                logger.info(f"   - BRUTAL_AGING: RAG 기반 의학적 노화")
                logger.info(f"   - 최종 프롬프트: {len(final_prompt)}자")
            else:
                # Replicate 전용 프롬프트
                final_prompt = self.assemble_replicate_prompt(aging_facts)
                logger.info(f"✅ Replicate 프롬프트 조립 완료")
                logger.info(f"   - Identity Anchor: {len(self.IDENTITY_ANCHOR)}자")
                logger.info(f"   - Gemini 팩트: {len(aging_facts)}자")
                logger.info(f"   - Texture Booster: {len(self.TEXTURE_BOOSTER)}자")
                logger.info(f"   - Technical Preset: {len(self.TECHNICAL_PRESET)}자")
                logger.info(f"   - 최종 프롬프트: {len(final_prompt)}자")
            
            # Step 4: Replicate SDXL 이미지 생성
            logger.info(f"\n[Step 4] 이미지 생성 ({self.image_model.upper()})")
            
            target_years = user_data.get('target_years', 10)
            
            if self.image_model == "replicate":
                # Replicate SDXL 사용
                dynamic_strength = self._calculate_dynamic_strength(target_years)
                dynamic_guidance = self._calculate_dynamic_guidance(target_years)
                dynamic_noise_frac = self._calculate_dynamic_noise_frac(target_years)
                
                logger.info(f"동적 파라미터:")
                logger.info(f"  - Target Years: {target_years}년")
                logger.info(f"  - Prompt Strength: {dynamic_strength}")
                logger.info(f"  - Guidance Scale: {dynamic_guidance}")
                logger.info(f"  - High Noise Frac: {dynamic_noise_frac}")
                
                image_url, local_path = self.generate_image_with_sdxl(
                    image_path, 
                    final_prompt,
                    prompt_strength=dynamic_strength,
                    guidance_scale=dynamic_guidance,
                    high_noise_frac=dynamic_noise_frac,
                    negative_prompt=self.REPLICATE_NEGATIVE_PROMPT
                )
            elif self.image_model == "openai":
                # OpenAI gpt-image-1 사용 (Image Edit)
                logger.info(f"gpt-image-1 생성 모드 (Image-to-Image)")
                logger.info(f"  - Target Years: {target_years}년")
                
                image_url, local_path = self.generate_image_with_gpt_image(
                    image_path,
                    final_prompt
                )
            elif self.image_model == "gemini-2.5-flash-image":
                # Gemini API 직접 사용 (이미지 생성)
                logger.info(f"Gemini 2.5 Flash 이미지 생성 (Gemini API)")
                logger.info(f"  - Target Years: {target_years}년")
                
                image_url, local_path = self.generate_image_with_gemini_api(
                    image_path,
                    final_prompt
                )
            elif self.image_model == "gemini-3-pro-image":
                # Gemini 3 Pro Image Preview 사용 (이미지 생성 지원)
                logger.info(f"Gemini 3.0 Pro Image 생성 (Gemini API)")
                logger.info(f"  - Target Years: {target_years}년")
                
                image_url, local_path = self.generate_image_with_gemini_pro_image(
                    image_path,
                    final_prompt
                )
            else:
                # Vertex AI Imagen 모델 사용
                logger.info(f"Gemini 이미지 생성 모드 (Vertex AI Imagen)")
                logger.info(f"  - Target Years: {target_years}년")
                
                image_url, local_path = self.generate_image_with_gemini(
                    image_path,
                    final_prompt
                )
            
            logger.info(f"✅ 이미지 생성 완료: {image_url}")
            if local_path:
                logger.info(f"✅ 로컬 저장: {local_path}")
            
            # 최종 결과
            result = {
                'image_url': image_url,
                'local_image_path': local_path,
                'korean_report': korean_report,
                'gemini_facts': aging_facts,
                'final_prompt': final_prompt,
                'evidence': evidence
            }
            
            logger.info("\n" + "=" * 80)
            logger.info("ImagePipeline 완료!")
            logger.info("=" * 80)
            
            return result
            
        except Exception as e:
            logger.error(f"파이프라인 실행 중 오류: {str(e)}")
            raise

    def search_evidence(self, user_data: Dict[str, Any]) -> list:
        """Step 1: RAG 검색"""
        try:
            query = self._create_search_query(user_data)
            query_vector = self.embedder.embed_text(query)
            
            search_results = self.qdrant_client.query_points(
                collection_name=self.collection_name,
                query=query_vector,
                limit=5,
                with_payload=True,
                with_vectors=False
            ).points
            
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
            
            return evidence_list
            
        except Exception as e:
            logger.error(f"RAG 검색 중 오류: {str(e)}")
            raise

    def _create_search_query(self, user_data: Dict[str, Any]) -> str:
        """검색 쿼리 생성"""
        age = user_data.get('age', 30)
        gender = user_data.get('gender', '남성')
        
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
        query = f"{age}세 {gender}의 피부 노화, {lifestyle_str}의 영향, 주름, 피부 처짐, 색소 침착"
        
        return query

    def generate_facts_with_gemini(self, user_data: Dict[str, Any], evidence: list) -> Dict[str, str]:
        """
        Step 2: Gemini로 순수 팩트만 생성 (What)
        
        Returns:
            dict: {
                'korean_report': 한글 분석 리포트,
                'aging_facts': 순수 노화 팩트 (영문)
            }
        """
        try:
            prompt = self._create_gemini_prompt(user_data, evidence)
            
            response = self.gemini_model.generate_content(prompt)
            response_text = response.text
            
            korean_report, aging_facts = self._parse_gemini_response(response_text)
            
            return {
                'korean_report': korean_report,
                'aging_facts': aging_facts
            }
            
        except Exception as e:
            logger.error(f"Gemini 분석 중 오류: {str(e)}")
            raise

    def _create_gemini_prompt(self, user_data: Dict[str, Any], evidence: list) -> str:
        """Gemini용 프롬프트 - 순수 팩트만 요청"""
        
        evidence_text = "\n\n".join([
            f"[논문 {e['rank']}] (근거 수준: {e['evidence_level']}, 유사도: {e['score']})\n{e['text'][:500]}"
            for e in evidence
        ])
        
        age = user_data.get('age', 30)
        gender = user_data.get('gender', '남성')
        smoking = "흡연자" if user_data.get('smoking') else "비흡연자"
        drinking = "음주" if user_data.get('drinking') else "비음주"
        stress = user_data.get('stress_level', 5)
        sleep = user_data.get('sleep_hours', 7)
        exercise = user_data.get('exercise_frequency', 3)
        
        prompt = f"""You are a medical aging analyst. Your ONLY job is to describe BIOLOGICAL AGING FACTS based on paper evidence.

## Your Role (CRITICAL)
DO NOT include any:
- Photography terms (8k, macro, lens, lighting, etc.)
- Technical specifications
- Quality markers (masterpiece, professional, etc.)
- Identity preservation instructions

ONLY provide:
- Pure biological aging descriptions
- Anatomical changes with measurements
- Medical terminology for skin aging
- Clinical observations from papers

## Analysis Data
# Paper Evidence:
{evidence_text}

# User Data:
- Age: {age}
- Gender: {gender}
- Smoking: {smoking}
- Drinking: {drinking}
- Stress Level: {stress}/10
- Sleep Hours: {sleep} hours
- Exercise Frequency: {exercise} times/week

## Output Format (MUST FOLLOW)

[한글 리포트]
(Write detailed Korean report analyzing aging patterns based on papers)
- Include numerical data from papers (mm, cm, %)
- Lifestyle impact analysis
- Prevention recommendations
- Be factual and scientific

[영문 노화 팩트]
(Write ONLY biological aging facts in English, 200-300 words)

Example format (FOLLOW THIS STYLE):
"A {age}-year-old {gender} showing accelerated biological aging. Forehead: bilateral horizontal rhytides with 2-3mm depth, loss of skin elasticity. Periorbital region: pronounced crow's feet extending laterally, infraorbital hollowing, dark circles from chronic sleep deprivation. Nasolabial area: deep bilateral folds measuring approximately 3-4mm depth, exacerbated by collagen degradation from smoking. Cheeks: scattered solar lentigines, uneven melanin distribution, visible hyperpigmentation patches. Jawline: early jowling, reduced definition from elastin breakdown. Skin texture: rough, leathery appearance from cumulative UV damage, visible enlarged pores on T-zone, mottled skin tone. Vascular changes: visible telangiectasia on cheeks, redness from alcohol-related vasodilation."

CRITICAL RULES:
1. NO photography/technical terms
2. NO quality markers
3. ONLY medical/anatomical descriptions
4. Use measurements from papers (mm, cm, %)
5. Focus on WHAT aging looks like, not HOW to photograph it

Generate both reports now:"""

        return prompt

    def _parse_gemini_response(self, response_text: str) -> tuple[str, str]:
        """Gemini 응답 파싱"""
        try:
            if "[영문 노화 팩트]" in response_text:
                parts = response_text.split("[영문 노화 팩트]")
            elif "[Aging Facts]" in response_text:
                parts = response_text.split("[Aging Facts]")
            else:
                parts = response_text.split("[영문")
            
            korean_part = parts[0].replace("[한글 리포트]", "").replace("[Korean Report]", "").strip()
            english_part = parts[1].strip() if len(parts) > 1 else ""
            
            # 영문 팩트 검증
            if len(english_part) < 100:
                logger.warning("⚠️ 영문 팩트가 너무 짧습니다. 기본값 사용")
                english_part = self._get_default_facts(user_data)
            
            return korean_part, english_part
            
        except Exception as e:
            logger.error(f"응답 파싱 중 오류: {str(e)}")
            return response_text, self._get_default_facts({})

    def _get_default_facts(self, user_data: Dict[str, Any]) -> str:
        """기본 노화 팩트"""
        age = user_data.get('age', 35)
        gender = user_data.get('gender', '남성')
        return f"""A {age}-year-old {gender} showing natural biological aging. Forehead: horizontal rhytides with moderate depth. Periorbital region: crow's feet wrinkles, slight infraorbital hollowing. Nasolabial area: bilateral folds with visible depth. Skin texture: age-appropriate changes with some roughness, visible pores. Overall appearance: consistent with chronological age and lifestyle factors."""

    def assemble_replicate_prompt(self, aging_facts: str) -> str:
        """
        Step 3-A: Replicate SDXL 전용 프롬프트 조립
        
        조립 순서:
        1. Identity Anchor (제일 앞 - 최우선)
        2. Aging Facts (Gemini가 생성한 순수 팩트)
        3. Texture Booster (노골적 질감 강조)
        4. Technical Preset (사진 기술 스펙)
        
        Args:
            aging_facts: Gemini가 생성한 노화 팩트
            
        Returns:
            str: 최종 조립된 프롬프트
        """
        final_prompt = f"""{self.IDENTITY_ANCHOR}

[BIOLOGICAL_AGING_FACTS]: {aging_facts}

{self.TEXTURE_BOOSTER}

{self.TECHNICAL_PRESET}"""
        
        return final_prompt
    
    def assemble_gpt_prompt(self, aging_facts: str) -> str:
     prompt = f"""[IMAGE_EDIT_TASK]: Aged version of the provided subject.
    
[STRICT_IDENTITY_CONSTRAINT]: 
- THIS IS NOT A NEW CHARACTER. This is the SPECIFIC PERSON from the input image.
- DO NOT change the person's ethnicity, eye color, or basic facial geometry.
{self.GPT_IDENTITY_LOCK}

[AGING_SPECIFICATIONS - APPLY AS TEXTURE OVERLAY]:
{aging_facts}

[VISUAL_STYLE]: 
- Brutal realism, raw photography. 
- Side-lighting to emphasize skin texture. 
- 8k resolution, macro-lens detail of the existing face.
- NO AI smoothing, NO facial reconstruction."""
     return prompt
    
    def assemble_gemini_prompt(self, aging_facts: str) -> str:
        """
        Step 3-C: Gemini 이미지 생성 전용 프롬프트 조립 (Visual Anchoring)
        
        Gemini 전략:
        1. 시각적 앵커링 (Visual Anchoring): 원본 이미지의 특징을 하나하나 지적하며 고정
        2. 픽셀 단위 구조 보존 강조
        3. 의학적 시각화로 프레이밍 ('Aging' → 'Medical Pathology Visualization')
        4. 텍스처 강조 (거친 피부, Raw RAW photo, Hyper-detailed skin pores)
        5. 조명 설정 (Dramatic side-lighting)
        
        핵심 차별점:
        - Gemini는 이미지를 "이해"할 수 있으므로 원본의 특징을 하나하나 짚어주며 고정
        - 'Brutal Aging'이 아닌 'Medical Pathology Visualization'로 프레이밍하여 필터 우회
        
        Args:
            aging_facts: Gemini가 생성한 노화 팩트
            
        Returns:
            str: Gemini 최적화된 프롬프트
        """
        prompt = f"""[SYSTEM_INSTRUCTION]:
You are a 'Texture Retouching Specialist' who preserves 100% of the original image's pixel-level structure while adding ONLY biological aging textures.

[IDENTITY_LOCK - CRITICAL]:
**Pixel-level preservation is mandatory.**
- Keep the EXACT position of facial features (eyes, nose, mouth).
- Do NOT change the iris color or eye shape.
- Preserve the skeletal structure (bone structure) of the face completely.
- The user's unique impression must remain unchanged. Any alteration to the overall facial identity is a failure.

[TASK_DEFINITION]:
This is NOT a simple 'aging filter'. This is a **Medical Pathology Visualization** task.
You must simulate how this specific individual's face will degrade biologically over time, based on clinical evidence.

[BRUTAL_AGING - RAG-BASED]:
Apply ruthlessly realistic aging effects ONLY to the skin surface. Based on the provided clinical data:
{aging_facts}

Specific aging manifestations to add:
- Deeply carved nasolabial folds (deep wrinkles from nose to mouth corners)
- Irregular age spots (solar lentigines) with varying pigmentation
- Mottled skin tone with visible redness (erythema) and broken capillaries
- Leathery, weathered skin texture (rough, dry, sagging)
- Gravity-induced sagging jawline (jowls) and ptosis

[TEXTURE_EMPHASIS]:
- **Hyper-detailed skin pores**: Every pore must be visible, not smoothed out.
- **Raw RAW photo quality**: No glossy finish, no artificial smoothness.
- **Rough, patchy texture**: Simulate cumulative UV damage and dehydration.
- **Visible telangiectasia**: Fine red lines (broken capillaries) on cheeks and nose.

[LIGHTING_SETUP]:
- **Dramatic side-lighting**: Use harsh directional light to accentuate every wrinkle's depth.
- Cast shadows in every skin crevice to create brutal realism.
- Avoid soft, flattering light. Use Rembrandt lighting to expose skin imperfections.

[FINAL_INSTRUCTION]:
Generate an aged version of the input photo. The result must be:
1. The SAME person (100% identity match)
2. Clinically accurate aging (based on RAG data)
3. Brutally realistic texture (no beauty filters)
4. Medical-grade visualization (not a cosmetic 'age progression')"""
        
        return prompt
    
    def assemble_prompt(self, aging_facts: str) -> str:
        """
        [DEPRECATED] 기존 호환성을 위해 유지 (내부적으로 assemble_replicate_prompt 호출)
        """
        return self.assemble_replicate_prompt(aging_facts)

    def _calculate_dynamic_strength(self, target_years: int) -> float:
        """동적 prompt_strength 계산"""
        base_strength = 0.43
        additional_strength = (target_years // 10) * 0.025
        final_strength = min(base_strength + additional_strength, 0.55)
        return round(final_strength, 2)

    def _calculate_dynamic_guidance(self, target_years: int) -> float:
        """동적 guidance_scale 계산"""
        if target_years < 10:
            return 10.0
        elif target_years < 20:
            return 11.0
        else:
            return 12.0

    def _calculate_dynamic_noise_frac(self, target_years: int) -> float:
        """동적 high_noise_frac 계산"""
        if target_years < 15:
            return 0.70
        else:
            return 0.65

    def generate_image_with_sdxl(self, image_path: str, prompt: str, 
                                 prompt_strength: float = 0.50,
                                 guidance_scale: float = 12.0,
                                 high_noise_frac: float = 0.65,
                                 negative_prompt: str = None) -> tuple[str, str]:
        """Step 4-A: Replicate SDXL 이미지 생성 (Image-to-Image)"""
        try:
            with open(image_path, 'rb') as image_file:
                image_data = base64.b64encode(image_file.read()).decode('utf-8')
                image_uri = f"data:image/jpeg;base64,{image_data}"
            
            logger.info(f"이미지 로드: {image_path}")
            logger.info(f"📊 SDXL 파라미터:")
            logger.info(f"   - Prompt Strength: {prompt_strength}")
            logger.info(f"   - Guidance Scale: {guidance_scale}")
            logger.info(f"   - High Noise Frac: {high_noise_frac}")
            
            # 최종 프롬프트 출력
            logger.info(f"\n{'='*80}")
            logger.info(f"🎨 Replicate SDXL에 전달되는 최종 프롬프트:")
            logger.info(f"{'='*80}")
            logger.info(f"{prompt}")
            logger.info(f"{'='*80}\n")
            
            output = replicate.run(
                "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
                input={
                    "image": image_uri,
                    "prompt": prompt,
                    "negative_prompt": negative_prompt if negative_prompt else self.REPLICATE_NEGATIVE_PROMPT,
                    "prompt_strength": prompt_strength,
                    "num_outputs": 1,
                    "num_inference_steps": 30,
                    "guidance_scale": guidance_scale,
                    "scheduler": "DPMSolverMultistep",
                    "refine": "expert_ensemble_refiner",
                    "high_noise_frac": high_noise_frac
                }
            )
            
            if isinstance(output, list) and len(output) > 0:
                image_url = output[0]
            else:
                image_url = str(output)
            
            local_path = self._download_image(image_url, "replicate")
            
            return image_url, local_path
            
        except Exception as e:
            logger.error(f"SDXL 이미지 생성 중 오류: {str(e)}")
            raise

    def generate_image_with_gpt_image(self, image_path: str, prompt: str) -> tuple[str, str]:
        """Step 4-B: OpenAI gpt-image-1 이미지 편집 (Image-to-Image)"""
        try:
            # gpt-image-1은 최대 4000자 제한
            if len(prompt) > 4000:
                logger.warning(f"⚠️ 프롬프트가 너무 깁니다 ({len(prompt)}자). 4000자로 자릅니다.")
                prompt = prompt[:4000]
            
            logger.info(f"원본 이미지 로드: {image_path}")
            logger.info(f"\n{'='*80}")
            logger.info(f"🎨 gpt-image-1에 전달되는 최종 프롬프트:")
            logger.info(f"{'='*80}")
            logger.info(f"{prompt}")
            logger.info(f"{'='*80}\n")
            
            logger.info("gpt-image-1 API 호출 중... (30-60초 소요)")
            
            # 이미지 파일 열기
            with open(image_path, 'rb') as image_file:
                response = self.openai_client.images.edit(
                    model="gpt-image-1",
                    image=image_file,
                    prompt=prompt,
                    n=1,
                    size="1024x1024"
                )
            
            logger.info(f"✅ gpt-image-1 API 응답 수신")
            
            # 응답 구조 디버깅
            logger.info(f"📋 response.data[0] 타입: {type(response.data[0])}")
            logger.info(f"📋 response.data[0] 속성: {dir(response.data[0])}")
            
            # URL 또는 Base64 확인
            image_url = response.data[0].url if hasattr(response.data[0], 'url') else None
            b64_data = response.data[0].b64_json if hasattr(response.data[0], 'b64_json') else None
            
            logger.info(f"📋 URL 존재 여부: {image_url is not None} (값: {image_url})")
            logger.info(f"📋 Base64 존재 여부: {b64_data is not None}")
            
            if b64_data:
                # Base64로 반환된 경우
                logger.info("📦 Base64 이미지 데이터 디코딩 중...")
                image_data = base64.b64decode(b64_data)
                
                # 로컬에 PNG로 저장
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                local_path = f"result_gpt_image_{timestamp}.png"
                with open(local_path, 'wb') as f:
                    f.write(image_data)
                logger.info(f"✅ 이미지 저장 완료: {local_path}")
                
                return None, local_path  # URL은 없고 로컬 경로만 반환
            
            elif image_url:
                # URL로 반환된 경우
                logger.info(f"🔗 URL로 반환됨: {image_url}")
                local_path = self._download_image(image_url, "gpt_image")
                return image_url, local_path
            
            else:
                logger.error(f"❌ URL도 Base64도 없습니다")
                raise ValueError("gpt-image-1 응답에 url 또는 b64_json이 없습니다")
            
            return image_url, local_path
            
        except Exception as e:
            logger.error(f"gpt-image-1 이미지 생성 중 오류: {str(e)}")
            raise

    def generate_image_with_gemini(self, image_path: str, prompt: str) -> tuple[str, str]:
        """
        Step 4-D: Vertex AI Imagen 3를 통한 이미지 편집
        
        Imagen 3의 edit_image 기능을 사용하여 원본 이미지를 기반으로 노화 효과 적용
        """
        try:
            logger.info(f"원본 이미지 로드: {image_path}")
            logger.info(f"\n{'='*80}")
            logger.info(f"🎨 Vertex AI Imagen 3에 전달되는 최종 프롬프트:")
            logger.info(f"{'='*80}")
            logger.info(f"{prompt}")
            logger.info(f"{'='*80}\n")
            
            logger.info("Vertex AI Imagen 3 API 호출 중... (30-90초 소요)")
            
            # 이미지 파일 읽기
            from vertexai.preview.vision_models import Image as VertexImage
            
            base_image = VertexImage.load_from_file(image_path)
            
            # Imagen 3 edit_image 호출
            # 참고: edit_image는 mask 없이 전체 이미지를 프롬프트에 따라 수정
            response = self.imagen_model.edit_image(
                base_image=base_image,
                prompt=prompt,
                # 파라미터 튜닝
                number_of_images=1,
                guidance_scale=15,  # 프롬프트 충실도 (높을수록 프롬프트 준수)
                # seed=42,  # 재현성을 위한 시드 (선택사항)
            )
            
            logger.info(f"✅ Vertex AI Imagen 3 API 응답 수신")
            
            # 생성된 이미지 저장
            if response.images:
                generated_image = response.images[0]
                
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                local_path = f"result_imagen_{timestamp}.png"
                
                # 이미지 저장
                generated_image.save(local_path)
                logger.info(f"✅ 이미지 저장 완료: {local_path}")
                
                # Imagen은 URL을 직접 반환하지 않으므로 None 반환
                return None, local_path
            else:
                raise ValueError("Imagen 3가 이미지를 생성하지 못했습니다.")
            
        except Exception as e:
            logger.error(f"Vertex AI Imagen 3 이미지 생성 중 오류: {str(e)}")
            
            # 오류 메시지가 인증 관련인 경우 자세한 안내
            if "credentials" in str(e).lower() or "authentication" in str(e).lower():
                logger.error("=" * 80)
                logger.error("❌ GCP 인증 오류 발생!")
                logger.error("=" * 80)
                logger.error("Vertex AI Imagen 3를 사용하려면 다음 단계를 수행하세요:")
                logger.error("")
                logger.error("1. GCP 프로젝트 생성 및 설정:")
                logger.error("   - https://console.cloud.google.com/")
                logger.error("   - 새 프로젝트 생성 또는 기존 프로젝트 선택")
                logger.error("   - Vertex AI API 활성화")
                logger.error("")
                logger.error("2. 인증 설정 (다음 중 하나):")
                logger.error("   A. gcloud CLI 사용 (권장):")
                logger.error("      gcloud auth application-default login")
                logger.error("")
                logger.error("   B. 서비스 계정 키 사용:")
                logger.error("      - GCP Console > IAM > Service Accounts")
                logger.error("      - 서비스 계정 생성 및 JSON 키 다운로드")
                logger.error("      - .env에 추가: GOOGLE_APPLICATION_CREDENTIALS=path/to/key.json")
                logger.error("")
                logger.error("3. .env 파일 설정:")
                logger.error("   GOOGLE_CLOUD_PROJECT=your-project-id")
                logger.error("   GOOGLE_CLOUD_LOCATION=us-central1")
                logger.error("")
                logger.error("4. Imagen API 할당량 확인:")
                logger.error("   - Imagen 3는 유료 API입니다 (월 $0.02~$0.04/이미지)")
                logger.error("   - GCP 결제 계정 연결 필요")
                logger.error("=" * 80)
            
            raise

    def generate_image_with_gemini_api(self, image_path: str, prompt: str) -> tuple[str, str]:
        """
        Step 4-E: Gemini API 직접 사용한 이미지 생성
        
        Gemini 2.5 Flash 모델을 사용하여 이미지를 생성합니다.
        주의: Gemini API는 현재 이미지 생성보다는 이미지 이해에 특화되어 있습니다.
        """
        try:
            logger.info(f"원본 이미지 로드: {image_path}")
            logger.info(f"\n{'='*80}")
            logger.info(f"🎨 Gemini API에 전달되는 최종 프롬프트:")
            logger.info(f"{'='*80}")
            logger.info(f"{prompt}")
            logger.info(f"{'='*80}\n")
            
            logger.info("Gemini API 호출 중... (이미지 이해 + 설명 생성)")
            
            # 이미지 파일 읽기
            from PIL import Image as PILImage
            original_image = PILImage.open(image_path)
            
            # Gemini에 이미지와 프롬프트 전달
            # 현재 Gemini는 이미지 생성이 아닌 이미지 이해를 수행
            response = self.gemini_image_model.generate_content([
                prompt,
                original_image
            ])
            
            logger.info(f"✅ Gemini API 응답 수신")
            logger.info(f"📋 Gemini 응답: {response.text[:300]}...")
            
            # ⚠️ 중요: Gemini API는 아직 이미지 생성을 공식 지원하지 않음
            logger.warning("=" * 80)
            logger.warning("⚠️ Gemini API 제한사항")
            logger.warning("=" * 80)
            logger.warning("Gemini API(google-generativeai)는 현재 이미지 생성을 공식 지원하지 않습니다.")
            logger.warning("이미지 이해/분석만 가능하며, 생성은 Vertex AI Imagen을 사용해야 합니다.")
            logger.warning("")
            logger.warning("현재 동작:")
            logger.warning("1. 원본 이미지를 분석하여 노화 설명을 생성합니다")
            logger.warning("2. 원본 이미지를 복사하여 반환합니다 (실제 노화 효과 없음)")
            logger.warning("")
            logger.warning("실제 이미지 생성을 위한 옵션:")
            logger.warning("- 옵션 1: Replicate SDXL (권장)")
            logger.warning("- 옵션 2: OpenAI gpt-image-1")
            logger.warning("- 옵션 3/4: Vertex AI Imagen (GCP 결제 필요)")
            logger.warning("=" * 80)
            
            # 원본 이미지 복사 (임시 처리)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            local_path = f"result_gemini_api_{timestamp}.jpg"
            
            import shutil
            shutil.copy(image_path, local_path)
            logger.info(f"⚠️ 임시: 원본 이미지 복사 → {local_path}")
            
            return None, local_path
            
        except Exception as e:
            logger.error(f"Gemini API 호출 중 오류: {str(e)}")
            raise

    def generate_image_with_gemini_pro_image(self, image_path: str, prompt: str) -> tuple[str, str]:
        """
        Step 4-F: Gemini 3.0 Pro Image Preview를 사용한 이미지 생성
        
        gemini-3-pro-image-preview 모델은 이미지 생성을 지원합니다.
        원본 이미지와 프롬프트를 기반으로 노화된 이미지를 생성합니다.
        """
        try:
            logger.info(f"원본 이미지 로드: {image_path}")
            logger.info(f"\n{'='*80}")
            logger.info(f"🎨 Gemini 3.0 Pro Image에 전달되는 최종 프롬프트:")
            logger.info(f"{'='*80}")
            logger.info(f"{prompt}")
            logger.info(f"{'='*80}\n")
            
            logger.info("Gemini 3.0 Pro Image API 호출 중... (30-90초 소요)")
            
            # 이미지 파일 읽기
            from PIL import Image as PILImage
            original_image = PILImage.open(image_path)
            
            # Gemini 3.0 Pro Image Preview 모델에 이미지 편집 요청
            # generation_config에 이미지 생성 관련 설정 추가
            response = self.gemini_image_model.generate_content(
                [prompt, original_image],
                generation_config={
                    'temperature': 0.4,  # 창의성 낮춤 (Identity 보존)
                    'candidate_count': 1,
                }
            )
            
            logger.info(f"✅ Gemini 3.0 Pro Image API 응답 수신")
            
            # 응답 처리 - Gemini가 이미지를 생성한 경우
            if hasattr(response, 'parts') and response.parts:
                for part in response.parts:
                    # 이미지 데이터가 있는지 확인
                    if hasattr(part, 'inline_data') and part.inline_data:
                        logger.info("✅ 이미지 데이터 감지!")
                        
                        # Base64 이미지 데이터 추출
                        image_data = part.inline_data.data
                        mime_type = part.inline_data.mime_type
                        
                        # 로컬 저장
                        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                        file_ext = "png" if "png" in mime_type else "jpg"
                        local_path = f"result_gemini_3_pro_{timestamp}.{file_ext}"
                        
                        # Base64 디코딩 및 저장
                        import base64
                        with open(local_path, 'wb') as f:
                            f.write(base64.b64decode(image_data))
                        
                        logger.info(f"✅ 이미지 저장 완료: {local_path}")
                        return None, local_path
            
            # 이미지가 생성되지 않은 경우
            logger.warning("⚠️ 응답에 이미지 데이터가 없습니다. 텍스트 응답만 수신했습니다.")
            logger.info(f"📋 Gemini 응답: {response.text[:300]}...")
            
            # 원본 이미지 복사 (임시)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            local_path = f"result_gemini_3_pro_{timestamp}_fallback.jpg"
            import shutil
            shutil.copy(image_path, local_path)
            logger.info(f"⚠️ 임시: 원본 이미지 복사 → {local_path}")
            
            return None, local_path
            
        except Exception as e:
            logger.error(f"Gemini 3.0 Pro Image 생성 중 오류: {str(e)}")
            raise

    def generate_image_with_dalle(self, prompt: str) -> tuple[str, str]:
        """Step 4-C: OpenAI DALL-E 3 이미지 생성 (Text-to-Image) - 백업용"""
        try:
            # DALL-E 3는 최대 4000자 제한, 프롬프트 길이 확인
            if len(prompt) > 4000:
                logger.warning(f"⚠️ 프롬프트가 너무 깁니다 ({len(prompt)}자). 4000자로 자릅니다.")
                prompt = prompt[:4000]
            
            logger.info(f"\n{'='*80}")
            logger.info(f"🎨 DALL-E 3에 전달되는 최종 프롬프트:")
            logger.info(f"{'='*80}")
            logger.info(f"{prompt}")
            logger.info(f"{'='*80}\n")
            
            logger.info("DALL-E 3 API 호출 중... (30-60초 소요)")
            
            response = self.openai_client.images.generate(
                model="dall-e-3",
                prompt=prompt,
                size="1024x1024",  # dall-e-3: 1024x1024, 1024x1792, 1792x1024
                quality="hd",      # "standard" or "hd"
                n=1,
            )
            
            image_url = response.data[0].url
            logger.info(f"✅ DALL-E 3 이미지 생성 완료")
            
            # 이미지 다운로드
            local_path = self._download_image(image_url, "dalle")
            
            return image_url, local_path
            
        except Exception as e:
            logger.error(f"DALL-E 3 이미지 생성 중 오류: {str(e)}")
            raise

    def _download_image(self, image_url: str, source: str) -> str:
        """이미지 다운로드 및 로컬 저장"""
        import requests
        from datetime import datetime
        
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_filename = f"aged_{source}_{timestamp}.png"
            output_path = Path(__file__).parent / output_filename
            
            logger.info(f"이미지 다운로드 중: {image_url}")
            response = requests.get(image_url, timeout=30)
            response.raise_for_status()
            
            with open(output_path, 'wb') as f:
                f.write(response.content)
            
            logger.info(f"✅ 로컬 저장: {output_path}")
            return str(output_path)
            
        except Exception as e:
            logger.error(f"이미지 다운로드 실패: {e}")
            return None


def main():
    """테스트 실행"""
    try:
        user_data = {
            'age': 35,
            'gender': '남성',
            'smoking': True,
            'drinking': True,
            'stress_level': 8,
            'sleep_hours': 5,
            'exercise_frequency': 1,
            'target_years': 10
        }
        
        image_path = "sample_face.jpg"
        
        pipeline = ImagePipeline()
        result = pipeline.run(user_data, image_path)
        
        print("\n" + "=" * 80)
        print("최종 결과 (역할 분리 아키텍처)")
        print("=" * 80)
        print(f"\n[생성 이미지]\n{result['image_url']}")
        print(f"\n[로컬 경로]\n{result['local_image_path']}")
        print(f"\n[Gemini 팩트]\n{result['gemini_facts'][:200]}...")
        print(f"\n[최종 프롬프트 길이]: {len(result['final_prompt'])}자")
        
    except Exception as e:
        logger.error(f"테스트 실행 실패: {str(e)}")


if __name__ == "__main__":
    main()
