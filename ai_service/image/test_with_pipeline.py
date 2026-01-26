# ai_service/image/test_with_pipeline.py
"""
BioStream Pipeline을 사용한 실제 이미지 생성 테스트
sample_user_data.py의 프로필을 사용하여 테스트
"""

import os
import sys
from pathlib import Path

# biostream_pipeline.py import를 위한 경로 설정
current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

from biostream_pipeline import BioStreamPipeline
from sample_user_data import (
    get_profile, 
    print_profile_info, 
    ALL_PROFILES
)


def test_basic():
    """기본 테스트: 고위험 프로필 + sample_face.jpg"""
    print("\n" + "="*80)
    print("🧪 BioStream Pipeline 기본 테스트")
    print("="*80)
    
    # Step 1: 환경 확인
    print("\n[Step 1] 환경 확인")
    print("-" * 80)
    
    # 이미지 파일 확인
    image_path = current_dir / "sample_face.jpg"
    if not image_path.exists():
        print(f"❌ 이미지 파일 없음: {image_path}")
        print("   → image/ 폴더에 sample_face.jpg를 배치하세요")
        return
    print(f"✅ 이미지 파일: {image_path}")
    
    # .env 파일 확인
    env_file = current_dir.parent / ".env"
    if not env_file.exists():
        print(f"❌ .env 파일 없음: {env_file}")
        return
    
    from dotenv import load_dotenv
    load_dotenv(env_file)
    
    google_key = os.getenv("GOOGLE_API_KEY")
    replicate_key = os.getenv("REPLICATE_API_TOKEN")
    qdrant_url = os.getenv("QDRANT_URL", "http://localhost:6333")
    
    if not google_key:
        print("❌ GOOGLE_API_KEY가 .env에 없습니다")
        return
    print(f"✅ Google API Key: {google_key[:20]}...")
    
    if not replicate_key:
        print("❌ REPLICATE_API_TOKEN이 .env에 없습니다")
        return
    print(f"✅ Replicate API Token: {replicate_key[:20]}...")
    
    # Qdrant 연결 확인
    print(f"\n[Step 1-2] Qdrant 연결 확인")
    print("-" * 80)
    try:
        from qdrant_client import QdrantClient
        client = QdrantClient(qdrant_url)
        collections = client.get_collections()
        print(f"✅ Qdrant 연결 성공! ({qdrant_url})")
        print(f"   컬렉션: {[col.name for col in collections.collections]}")
    except Exception as e:
        print(f"❌ Qdrant 연결 실패: {e}")
        print("\n해결 방법:")
        print("   docker-compose up -d qdrant")
        return
    
    # Step 2: 프로필 로드
    print("\n[Step 2] 사용자 프로필 로드")
    print("-" * 80)
    user_data = get_profile('high_risk')
    print_profile_info(user_data)
    
    # Step 3: 파이프라인 실행
    print("\n[Step 3] BioStream Pipeline 실행")
    print("-" * 80)
    print("⏳ 처리 중... (1-3분 소요)")
    print("   [1/3] RAG 검색 (논문 근거 수집)")
    print("   [2/3] Gemini 분석 (한글 리포트 + 영문 프롬프트)")
    print("   [3/3] Replicate SDXL (이미지 생성)")
    
    try:
        # 파이프라인 초기화
        pipeline = BioStreamPipeline()
        
        # 파이프라인 실행
        result = pipeline.run(
            user_data=user_data,
            image_path=str(image_path)
        )
        
        # Step 4: 결과 출력
        print("\n" + "="*80)
        print("✅ 테스트 성공!")
        print("="*80)
        
        print(f"\n📊 결과:")
        print(f"   - 생성 이미지 URL: {result['image_url']}")
        print(f"   - 로컬 저장 경로: {result.get('local_image_path', '저장 안됨')}")
        print(f"   - 논문 근거: {len(result['evidence'])}개")
        
        print(f"\n📄 한글 리포트 (처음 300자):")
        print("-" * 80)
        print(result['korean_report'][:300])
        print("... (후략)")
        
        print(f"\n🎨 영문 프롬프트 (처음 200자):")
        print("-" * 80)
        print(result['raw_prompt'][:200])
        print("... (후략)")
        
        # 결과 저장
        output_file = current_dir / "test_result_pipeline.txt"
        with open(output_file, "w", encoding="utf-8") as f:
            f.write("="*80 + "\n")
            f.write("BioStream Pipeline 테스트 결과\n")
            f.write("="*80 + "\n\n")
            f.write(f"[생성 이미지]\n{result['image_url']}\n\n")
            f.write("="*80 + "\n")
            f.write("한글 분석 리포트\n")
            f.write("="*80 + "\n\n")
            f.write(result['korean_report'])
            f.write("\n\n" + "="*80 + "\n")
            f.write("영문 프롬프트 (Replicate SDXL)\n")
            f.write("="*80 + "\n\n")
            f.write(result['raw_prompt'])
            f.write("\n\n" + "="*80 + "\n")
            f.write("논문 근거 요약\n")
            f.write("="*80 + "\n\n")
            for i, evidence in enumerate(result['evidence'], 1):
                f.write(f"[{i}] {evidence['paper_id']}\n")
                f.write(f"    유사도: {evidence['score']:.4f}\n")
                f.write(f"    근거 수준: {evidence['evidence_level']}\n")
                f.write(f"    내용: {evidence['text'][:200]}...\n\n")
        
        print(f"\n💾 전체 결과 저장: {output_file}")
        
    except Exception as e:
        print(f"\n❌ 테스트 실패: {e}")
        import traceback
        traceback.print_exc()


def test_multiple_profiles():
    """여러 프로필로 테스트 (이미지 생성 없이 프롬프트만)"""
    print("\n" + "="*80)
    print("🧪 다중 프로필 테스트 (프롬프트 생성만)")
    print("="*80)
    
    image_path = current_dir / "sample_face.jpg"
    if not image_path.exists():
        print(f"❌ 이미지 파일 없음: {image_path}")
        return
    
    try:
        pipeline = BioStreamPipeline()
        
        for profile_name in ['high_risk', 'healthy', 'moderate_risk']:
            print(f"\n{'='*80}")
            print(f"📋 프로필: {profile_name}")
            print('='*80)
            
            user_data = get_profile(profile_name)
            print_profile_info(user_data)
            
            print("⏳ RAG 검색 + Gemini 분석 중...")
            
            # RAG 검색
            evidence = pipeline.search_evidence(user_data)
            print(f"✅ 논문 근거: {len(evidence)}개 수집")
            
            # Gemini 분석
            analysis = pipeline.analyze_with_gemini(user_data, evidence)
            print(f"✅ 리포트 길이: {len(analysis['korean_report'])}자")
            print(f"✅ 프롬프트 길이: {len(analysis['english_prompt'])}자")
            
            print(f"\n📄 프롬프트 미리보기:")
            print("-" * 80)
            print(analysis['english_prompt'][:200])
            print("... (후략)\n")
        
        print("\n" + "="*80)
        print("✅ 다중 프로필 테스트 완료!")
        print("="*80)
        
    except Exception as e:
        print(f"\n❌ 실패: {e}")
        import traceback
        traceback.print_exc()


def test_custom_profile():
    """사용자 정의 프로필 테스트"""
    print("\n" + "="*80)
    print("🧑‍💻 사용자 정의 프로필 테스트")
    print("="*80)
    
    print("\n정보를 입력하세요 (Enter로 건너뛰기 시 기본값):\n")
    
    age = input("나이 (기본: 35): ").strip()
    age = int(age) if age else 35
    
    gender = input("성별 (남성/여성, 기본: 남성): ").strip()
    gender = gender if gender else "남성"
    
    smoking_input = input("흡연 (예/아니오, 기본: 예): ").strip()
    smoking = smoking_input.lower() in ['예', 'y', 'yes', ''] or smoking_input == ''
    
    drinking_input = input("음주 (예/아니오, 기본: 예): ").strip()
    drinking = drinking_input.lower() in ['예', 'y', 'yes', ''] or drinking_input == ''
    
    stress = input("스트레스 (0-10, 기본: 8): ").strip()
    stress = int(stress) if stress else 8
    
    sleep = input("수면 시간(시간, 기본: 5): ").strip()
    sleep = float(sleep) if sleep else 5.0
    
    exercise = input("운동 빈도(회/주, 기본: 1): ").strip()
    exercise = int(exercise) if exercise else 1
    
    custom_data = {
        'age': age,
        'gender': gender,
        'smoking': smoking,
        'drinking': drinking,
        'stress_level': stress,
        'sleep_hours': sleep,
        'exercise_frequency': exercise,
        'uv_exposure': True,
        'sunscreen_use': False,
    }
    
    print("\n✅ 사용자 정의 프로필 생성 완료!")
    print_profile_info(custom_data)
    
    # 파이프라인 실행
    image_path = current_dir / "sample_face.jpg"
    if not image_path.exists():
        print(f"❌ 이미지 없음: {image_path}")
        return
    
    try:
        pipeline = BioStreamPipeline()
        
        print("⏳ 파이프라인 실행 중...")
        result = pipeline.run(user_data=custom_data, image_path=str(image_path))
        
        print(f"\n✅ 완료!")
        print(f"   이미지: {result['image_url']}")
        print(f"   논문: {len(result['evidence'])}개")
        
    except Exception as e:
        print(f"❌ 실패: {e}")


def main():
    """메인 함수"""
    print("\n🧪 BioStream Pipeline 테스트 도구")
    print("\n옵션을 선택하세요:")
    print("1. 기본 테스트 (고위험 프로필 + 실제 이미지 생성)")
    print("2. 다중 프로필 테스트 (프롬프트만, 이미지 생성 X)")
    print("3. 사용자 정의 프로필 테스트")
    print("4. 종료")
    
    choice = input("\n선택 (1-4): ").strip()
    
    if choice == "1":
        test_basic()
    elif choice == "2":
        test_multiple_profiles()
    elif choice == "3":
        test_custom_profile()
    elif choice == "4":
        print("종료합니다.")
    else:
        print("잘못된 선택입니다.")


if __name__ == "__main__":
    main()
