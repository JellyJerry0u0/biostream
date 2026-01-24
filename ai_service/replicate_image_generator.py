"""
Replicate API를 사용한 Image-to-Image 생성
Vertex AI Imagen RAI 정책 우회 대안

설치:
  pip install replicate

사용법:
  python replicate_image_generator.py
"""

import os
import replicate

def generate_with_replicate(
    base_image_path: str,
    prompt: str,
    output_path: str = "output_replicate.png"
) -> str:
    """Replicate API로 Image-to-Image 생성
    
    Args:
        base_image_path: 기준 이미지 경로
        prompt: 생성 프롬프트
        output_path: 결과 저장 경로
    
    Returns:
        생성된 이미지 경로
    """
    
    # Replicate API 키 설정 (https://replicate.com/account/api-tokens)
    api_token = os.getenv("REPLICATE_API_TOKEN")
    if not api_token:
        raise ValueError(
            "REPLICATE_API_TOKEN 환경 변수를 설정하세요.\n"
            "1. https://replicate.com/account/api-tokens 에서 토큰 생성\n"
            "2. 환경 변수 설정: set REPLICATE_API_TOKEN=your_token"
        )
    
    print(f"📸 기준 이미지: {base_image_path}")
    print(f"📝 프롬프트: {prompt[:100]}...")
    
    # 이미지 파일 열기
    with open(base_image_path, "rb") as f:
        image_data = f.read()
    
    # Stable Diffusion XL Image-to-Image 모델 사용
    print("\n🎨 Replicate API 호출 중...")
    output = replicate.run(
        "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
        input={
            "image": image_data,  # 기준 이미지
            "prompt": prompt,  # Gemini가 생성한 프롬프트
            "strength": 0.4,  # 0-1 (낮을수록 원본 유지)
            "num_outputs": 1,
            "num_inference_steps": 30,
            "guidance_scale": 7.5,
        }
    )
    
    # 결과 이미지 다운로드
    import urllib.request
    image_url = output[0]
    print(f"✅ 생성 완료: {image_url}")
    
    urllib.request.urlretrieve(image_url, output_path)
    print(f"💾 저장 완료: {output_path}")
    
    return output_path


def generate_with_flux(
    base_image_path: str,
    prompt: str,
    output_path: str = "output_flux.png"
) -> str:
    """Flux (최신 모델) 사용
    
    더 고품질, 더 비쌈 ($0.03/이미지)
    """
    
    api_token = os.getenv("REPLICATE_API_TOKEN")
    if not api_token:
        raise ValueError("REPLICATE_API_TOKEN 필요")
    
    with open(base_image_path, "rb") as f:
        image_data = f.read()
    
    print("\n🎨 Flux 모델 사용 중...")
    output = replicate.run(
        "black-forest-labs/flux-dev",
        input={
            "image": image_data,
            "prompt": prompt,
            "strength": 0.3,  # Flux는 더 낮게
            "num_outputs": 1,
            "guidance_scale": 3.5,  # Flux는 낮은 CFG 사용
        }
    )
    
    import urllib.request
    image_url = output[0]
    urllib.request.urlretrieve(image_url, output_path)
    print(f"✅ 생성 완료: {output_path}")
    
    return output_path


if __name__ == "__main__":
    # 테스트
    
    # 1. generated_prompt.txt에서 프롬프트 읽기
    try:
        with open("generated_prompt.txt", "r", encoding="utf-8") as f:
            content = f.read()
            # [프롬프트] 섹션 추출
            prompt_start = content.find("[프롬프트]")
            if prompt_start != -1:
                prompt_section = content[prompt_start:]
                lines = prompt_section.split("\n")[1:]  # 첫 줄 제외
                prompt = ""
                for line in lines:
                    if line.strip().startswith("="):
                        break
                    prompt += line + "\n"
                prompt = prompt.strip()
            else:
                raise ValueError("프롬프트를 찾을 수 없습니다.")
    except FileNotFoundError:
        print("❌ generated_prompt.txt 파일이 없습니다.")
        print("먼저 aging_image_generator.py를 실행하세요.")
        exit(1)
    
    # 2. 기준 이미지
    base_image = "sample_face.jpg"
    if not os.path.exists(base_image):
        print(f"❌ {base_image} 파일이 없습니다.")
        exit(1)
    
    # 3. 이미지 생성
    print("\n" + "="*80)
    print("Replicate API로 Image-to-Image 생성")
    print("="*80)
    
    try:
        # SDXL 사용 (저렴, $0.01/이미지)
        result = generate_with_replicate(
            base_image_path=base_image,
            prompt=prompt,
            output_path="output_replicate_sdxl.png"
        )
        
        print("\n" + "="*80)
        print(f"✅ 생성 완료: {result}")
        print("="*80)
        
    except Exception as e:
        print(f"\n❌ 실패: {e}")
        print("\n해결 방법:")
        print("1. pip install replicate")
        print("2. https://replicate.com/account/api-tokens 에서 API 토큰 생성")
        print("3. 환경 변수 설정:")
        print("   Windows: set REPLICATE_API_TOKEN=your_token")
        print("   Linux/Mac: export REPLICATE_API_TOKEN=your_token")
