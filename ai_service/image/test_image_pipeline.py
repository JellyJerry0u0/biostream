# ai_service/image/test_image_pipeline.py
"""
ImagePipeline 테스트 스크립트 (역할 분리 아키텍처)
"""

import os
import sys
from pathlib import Path

current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

from image_pipeline import ImagePipeline
from sample_user_data import get_profile, print_profile_info


def test_new_architecture():
    """새로운 역할 분리 아키텍처 테스트"""
    print("\n" + "=" * 80)
    print("🧪 ImagePipeline 테스트 (역할 분리 아키텍처)")
    print("=" * 80)
    print("\n역할 분리:")
    print("  1. Gemini → 순수 팩트 생성 (What)")
    print("  2. Python → 프롬프트 조립 (How)")
    print("  3. 이미지 생성 모델 → 이미지 생성 (Execute)")
    
    # 이미지 생성 모델 선택
    print("\n" + "-" * 80)
    print("🎨 이미지 생성 모델 선택")
    print("-" * 80)
    print("1. Replicate SDXL (Image-to-Image, 고품질, 권장)")
    print("2. OpenAI gpt-image-1 (Image-to-Image, 원본 이미지 편집)")
    print("3. Gemini 3.0 Pro (Vertex AI Imagen, GCP 결제 필요)")
    print("4. Gemini 2.5 Flash (Vertex AI Imagen, GCP 결제 필요)")
    print("5. Gemini 2.5 Flash Image (Gemini API 직접, ⚠️ 실험적)")
    print("6. Gemini 3.0 Pro Image Preview (Gemini API, 이미지 생성 지원)")
    
    choice = input("\n선택 (1/2/3/4/5/6): ").strip()
    
    if choice == "1":
        image_model = "replicate"
        print("✅ Replicate SDXL 선택")
    elif choice == "2":
        image_model = "openai"
        print("✅ OpenAI gpt-image-1 선택")
    elif choice == "3":
        image_model = "gemini-imagen"
        print("✅ Gemini 3.0 Pro Image (Vertex AI) 선택")
    elif choice == "4":
        image_model = "gemini-flash-imagen"
        print("✅ Gemini 2.5 Flash Image (Vertex AI) 선택")
    elif choice == "5":
        image_model = "gemini-2.5-flash-image"
        print("✅ Gemini 2.5 Flash (Gemini API 직접) 선택")
        print("⚠️  실험적 모델입니다. 이미지 생성이 제한적일 수 있습니다.")
    elif choice == "6":
        image_model = "gemini-3-pro-image"
        print("✅ Gemini 3.0 Pro Image Preview (이미지 생성 지원) 선택")
    else:
        print("❌ 잘못된 선택입니다. 기본값(Replicate) 사용")
        image_model = "replicate"
    
    # 환경 확인
    image_path = current_dir / "sample_face.jpg"
    if image_model == "replicate" and not image_path.exists():
        print(f"\n❌ 오류: {image_path} 파일이 없습니다.")
        print("   Replicate는 원본 이미지가 필요합니다.")
        return
    
    # 프로필 로드
    print("\n" + "-" * 80)
    print("📋 사용자 프로필")
    print("-" * 80)
    profile = get_profile("HIGH_RISK")
    print_profile_info(profile)
    
    # 파이프라인 실행
    print("\n" + "-" * 80)
    print("⏳ 처리 중...")
    print("-" * 80)
    
    try:
        pipeline = ImagePipeline(image_model=image_model)
        result = pipeline.run(profile, str(image_path) if image_path.exists() else None)
        
        print("\n" + "=" * 80)
        print("✅ 테스트 성공!")
        print("=" * 80)
        
        print(f"\n📊 결과:")
        print(f"   - 이미지 모델: {image_model.upper()}")
        print(f"   - 이미지 URL: {result['image_url']}")
        print(f"   - 로컬 경로: {result['local_image_path']}")
        print(f"   - 논문 근거: {len(result['evidence'])}개")
        
        print(f"\n📄 한글 리포트 (처음 300자):")
        print("-" * 80)
        print(result['korean_report'][:300])
        print("... (후략)")
        
        print(f"\n🧬 Gemini 팩트 (순수 노화 묘사):")
        print("-" * 80)
        print(result['gemini_facts'][:300])
        print("... (후략)")
        
        print(f"\n🎨 최종 프롬프트 구조:")
        print("-" * 80)
        if image_model in ["gemini-imagen", "gemini-flash-imagen", "gemini-2.5-flash-image", "gemini-3-pro-image"]:
            print(f"   - Gemini Visual Anchoring 구조")
            print(f"   - System Instruction: 텍스처 리터칭 전문가")
            print(f"   - Identity Lock: 픽셀 단위 보존")
            print(f"   - RAG Facts: {len(result['gemini_facts'])}자")
            print(f"   - Medical Pathology Visualization")
        elif image_model == "openai":
            print(f"   - GPT 레이어 구조")
            print(f"   - Identity Lock: {len(pipeline.GPT_IDENTITY_LOCK)}자")
            print(f"   - Gemini Facts: {len(result['gemini_facts'])}자")
            print(f"   - Additive Aging 방식")
        else:
            print(f"   - Identity Anchor: {len(pipeline.IDENTITY_ANCHOR)}자")
            print(f"   - Gemini Facts: {len(result['gemini_facts'])}자")
        print(f"   - Texture Booster: {len(pipeline.TEXTURE_BOOSTER)}자")
        print(f"   - Technical Preset: {len(pipeline.TECHNICAL_PRESET)}자")
        print(f"   - 총 길이: {len(result['final_prompt'])}자")
        
        # 결과 저장
        output_file = current_dir / f"test_result_{image_model}_pipeline.txt"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("=" * 80 + "\n")
            f.write(f"ImagePipeline 테스트 결과 ({image_model.upper()})\n")
            f.write("=" * 80 + "\n\n")
            
            f.write("=" * 80 + "\n")
            f.write("1. 한글 리포트\n")
            f.write("=" * 80 + "\n")
            f.write(result['korean_report'])
            
            f.write("\n\n" + "=" * 80 + "\n")
            f.write("2. Gemini 팩트 (순수 노화 묘사)\n")
            f.write("=" * 80 + "\n")
            f.write(result['gemini_facts'])
            
            f.write("\n\n" + "=" * 80 + "\n")
            f.write("3. Python 조립 - Identity Anchor\n")
            f.write("=" * 80 + "\n")
            f.write(pipeline.IDENTITY_ANCHOR)
            
            f.write("\n\n" + "=" * 80 + "\n")
            f.write("4. Python 조립 - Texture Booster\n")
            f.write("=" * 80 + "\n")
            f.write(pipeline.TEXTURE_BOOSTER)
            
            f.write("\n\n" + "=" * 80 + "\n")
            f.write("5. Python 조립 - Technical Preset\n")
            f.write("=" * 80 + "\n")
            f.write(pipeline.TECHNICAL_PRESET)
            
            f.write("\n\n" + "=" * 80 + "\n")
            f.write("6. 최종 조립된 프롬프트\n")
            f.write("=" * 80 + "\n")
            f.write(result['final_prompt'])
            
            f.write("\n\n" + "=" * 80 + "\n")
            f.write("7. 생성 정보\n")
            f.write("=" * 80 + "\n")
            f.write(f"이미지 모델: {image_model.upper()}\n")
            f.write(f"이미지 URL: {result['image_url']}\n")
            f.write(f"로컬 경로: {result['local_image_path']}\n")
            f.write(f"논문 근거: {len(result['evidence'])}개\n")
        
        print(f"\n💾 전체 결과 저장: {output_file}")
        
    except Exception as e:
        print(f"\n❌ 테스트 실패: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    test_new_architecture()
