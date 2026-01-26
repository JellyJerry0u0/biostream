# ai_service/image/test_aging_with_image.py
"""
실제 얼굴 이미지로 노화 시뮬레이션 테스트
Qdrant Docker + Replicate API 통합 테스트
"""

import os
import sys
from pathlib import Path

# 상위 디렉토리를 모듈 경로에 추가 (ai_service를 import하기 위해)
sys.path.insert(0, str(Path(__file__).parent.parent))

from aging_image_generator import (
    UserLifestyleData, 
    generate_aging_image_prompt_pipeline
)

def test_with_sample_face():
    """sample_face.jpg를 사용한 실제 이미지 생성 테스트"""
    
    print("\n" + "="*80)
    print("🧪 BioStream 노화 시뮬레이터 - 실제 이미지 생성 테스트")
    print("="*80)
    
    # Step 1: 환경 확인
    print("\n[Step 1] 환경 확인")
    print("-" * 80)
    
    # 1-1. 이미지 파일 확인
    image_path = Path(__file__).parent / "sample_face.jpg"
    if not image_path.exists():
        print(f"❌ 이미지 파일 없음: {image_path}")
        print("   → image/ 폴더에 sample_face.jpg를 배치하세요")
        return
    print(f"✅ 이미지 파일 확인: {image_path}")
    
    # 1-2. .env 파일 확인
    env_file = Path(__file__).parent.parent / ".env"
    if not env_file.exists():
        print(f"❌ .env 파일 없음: {env_file}")
        return
    print(f"✅ .env 파일 확인: {env_file}")
    
    # 1-3. API 키 확인
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
    
    print(f"✅ Qdrant URL: {qdrant_url}")
    
    # 1-4. Qdrant Docker 연결 확인
    print("\n[Step 1-4] Qdrant Docker 연결 확인")
    print("-" * 80)
    try:
        from qdrant_client import QdrantClient
        client = QdrantClient(qdrant_url)
        collections = client.get_collections()
        print(f"✅ Qdrant 연결 성공!")
        print(f"   컬렉션 수: {len(collections.collections)}")
        for col in collections.collections:
            print(f"   - {col.name}: {col.points_count} points")
    except Exception as e:
        print(f"❌ Qdrant 연결 실패: {e}")
        print("\n해결 방법:")
        print("   1. Docker가 실행 중인지 확인: docker ps")
        print("   2. Qdrant 컨테이너 확인: docker ps | grep qdrant")
        print("   3. Qdrant 시작: docker-compose up -d qdrant")
        return
    
    # Step 2: 테스트 설문 데이터 준비
    print("\n[Step 2] 테스트 설문 데이터 준비")
    print("-" * 80)
    
    # 샘플 사용자 데이터 (하드코딩 → 실제 설문 응답으로 대체 가능)
    test_user = UserLifestyleData(
        user_id=999,
        age=35,
        gender="male",
        outcomes=["wrinkle", "pigmentation", "general_aging"],
        target_years=10,
        
        # 수면 (나쁜 케이스)
        sleep_hours_weekday=5.5,
        sleep_hours_weekend=7.0,
        sleep_quality_score=6.0,
        
        # 자외선 (나쁜 케이스)
        uv_exposure_10to16=">2h",
        sunscreen_frequency="sometimes",
        sunscreen_reapply="never",
        outdoor_sports_uv="weekly",
        
        # 음주/흡연 (나쁜 케이스)
        drinking_days_per_week="2-3",
        drinking_amount_per_session="소주 반병",
        smoking_status="current",
        smoking_amount_per_day="반갑",
        
        # 스트레스/카페인 (나쁜 케이스)
        stress_score=8.0,
        caffeine_intake="3+",
        caffeine_timing="evening",
        
        # 운동 (나쁜 케이스)
        aerobic_weekly="0",
        resistance_weekly="0",
        
        # 신체 정보
        height=175.0,
        weight=75.0,
        
        # 피부 상태
        skin_type="combination",
        skin_concerns=["wrinkle", "pigmentation", "dryness"],
        skin_satisfaction=5.0
    )
    
    print("✅ 테스트 사용자 프로필:")
    print(f"   나이: {test_user.age}세, 성별: {test_user.gender}")
    print(f"   예측 기간: {test_user.target_years}년 후")
    print(f"   흡연: {test_user.smoking_status}, 음주: {test_user.drinking_days_per_week}일/주")
    print(f"   수면: {test_user.sleep_hours_weekday}시간/일")
    print(f"   스트레스: {test_user.stress_score}/10")
    print(f"   운동: 유산소 {test_user.aerobic_weekly}회, 근력 {test_user.resistance_weekly}회")
    
    # Step 3: 파이프라인 실행 (이미지 생성 포함)
    print("\n[Step 3] 노화 시뮬레이션 파이프라인 실행")
    print("-" * 80)
    print("⏳ 처리 중... (1-3분 소요)")
    print("   - RAG 검색 (논문 근거)")
    print("   - Gemini 분석 (한글 리포트 + 영문 프롬프트)")
    print("   - Replicate SDXL 이미지 생성")
    
    output_path = Path(__file__).parent / "output_aged_face_test.png"
    
    try:
        result = generate_aging_image_prompt_pipeline(
            user_data=test_user,
            base_image_path=str(image_path),
            generate_image=True,  # 실제 이미지 생성 활성화
            output_image_path=str(output_path)
        )
        
        # Step 4: 결과 출력
        print("\n" + "="*80)
        print("✅ 테스트 성공!")
        print("="*80)
        
        print(f"\n📊 통계:")
        print(f"   - 검색된 논문: {result['evidence_count']}개")
        print(f"   - 사용된 쿼리: {len(result['queries_used'])}개")
        print(f"   - 리포트 길이: {len(result['report'])}자")
        print(f"   - 영문 프롬프트 길이: {len(result['imagen_prompt'])}자")
        
        if result['image_path']:
            print(f"\n🖼️ 생성된 이미지:")
            print(f"   입력: {result['base_image_path']}")
            print(f"   출력: {result['image_path']}")
            print(f"\n   → 이미지를 확인하세요: {result['image_path']}")
        else:
            print("\n⚠️ 이미지 생성 실패 (프롬프트는 생성됨)")
        
        print(f"\n📄 한글 리포트 미리보기:")
        print("-" * 80)
        print(result['report'][:500])
        print("... (후략)")
        
        print(f"\n🎨 영문 프롬프트 미리보기:")
        print("-" * 80)
        print(result['imagen_prompt'][:300])
        print("... (후략)")
        
        # 결과 파일 저장
        result_txt = Path(__file__).parent / "test_result.txt"
        with open(result_txt, "w", encoding="utf-8") as f:
            f.write("="*80 + "\n")
            f.write("BioStream 노화 시뮬레이션 결과\n")
            f.write("="*80 + "\n\n")
            f.write(f"[입력 이미지] {result['base_image_path']}\n")
            f.write(f"[출력 이미지] {result['image_path']}\n\n")
            f.write("="*80 + "\n")
            f.write("한글 분석 리포트\n")
            f.write("="*80 + "\n\n")
            f.write(result['report'])
            f.write("\n\n" + "="*80 + "\n")
            f.write("영문 프롬프트 (Replicate SDXL 사용)\n")
            f.write("="*80 + "\n\n")
            f.write(result['imagen_prompt'])
            f.write("\n\n" + "="*80 + "\n")
            f.write("시각적 상세 묘사\n")
            f.write("="*80 + "\n\n")
            f.write(result['visual_description'])
        
        print(f"\n💾 전체 결과 저장: {result_txt}")
        
    except Exception as e:
        print(f"\n❌ 테스트 실패: {e}")
        import traceback
        traceback.print_exc()
        
        print("\n📝 문제 해결 가이드:")
        print("   1. Qdrant가 실행 중인지 확인")
        print("   2. API 키가 유효한지 확인")
        print("   3. 네트워크 연결 확인")
        print("   4. 로그를 확인하여 정확한 오류 위치 파악")


def create_custom_test_data():
    """사용자 정의 테스트 데이터 생성 도우미"""
    print("\n" + "="*80)
    print("🧑‍💻 사용자 정의 테스트 데이터 생성")
    print("="*80)
    print("\n다음 정보를 입력하세요 (Enter로 건너뛰기 시 기본값 사용):\n")
    
    age = input("나이 (기본: 35): ").strip()
    age = int(age) if age else 35
    
    gender = input("성별 (male/female, 기본: male): ").strip()
    gender = gender if gender else "male"
    
    target_years = input("예측 기간(년, 기본: 10): ").strip()
    target_years = int(target_years) if target_years else 10
    
    smoking = input("흡연 여부 (current/former/never, 기본: current): ").strip()
    smoking = smoking if smoking else "current"
    
    drinking = input("음주 빈도(일/주, 기본: 2-3): ").strip()
    drinking = drinking if drinking else "2-3"
    
    sleep_hours = input("평균 수면 시간(시간, 기본: 5.5): ").strip()
    sleep_hours = float(sleep_hours) if sleep_hours else 5.5
    
    stress = input("스트레스 수준(0-10, 기본: 8): ").strip()
    stress = float(stress) if stress else 8.0
    
    custom_user = UserLifestyleData(
        user_id=1000,
        age=age,
        gender=gender,
        outcomes=["wrinkle", "pigmentation", "general_aging"],
        target_years=target_years,
        sleep_hours_weekday=sleep_hours,
        sleep_hours_weekend=sleep_hours + 1.5,
        sleep_quality_score=6.0,
        uv_exposure_10to16=">2h",
        sunscreen_frequency="sometimes",
        smoking_status=smoking,
        drinking_days_per_week=drinking,
        stress_score=stress,
        aerobic_weekly="0",
        height=175.0,
        weight=75.0,
        skin_type="combination",
        skin_concerns=["wrinkle", "pigmentation"],
        skin_satisfaction=5.0
    )
    
    print("\n✅ 사용자 정의 데이터 생성 완료!")
    return custom_user


def main():
    """메인 함수"""
    print("\n🧪 BioStream 노화 시뮬레이터 테스트 도구")
    print("\n옵션을 선택하세요:")
    print("1. 기본 테스트 (sample_face.jpg + 기본 설문 데이터)")
    print("2. 사용자 정의 테스트 (sample_face.jpg + 직접 입력)")
    print("3. 종료")
    
    choice = input("\n선택 (1-3): ").strip()
    
    if choice == "1":
        test_with_sample_face()
    elif choice == "2":
        custom_data = create_custom_test_data()
        
        image_path = Path(__file__).parent / "sample_face.jpg"
        output_path = Path(__file__).parent / "output_aged_face_custom.png"
        
        print("\n⏳ 파이프라인 실행 중...")
        try:
            result = generate_aging_image_prompt_pipeline(
                user_data=custom_data,
                base_image_path=str(image_path),
                generate_image=True,
                output_image_path=str(output_path)
            )
            print(f"\n✅ 완료! 결과 이미지: {output_path}")
        except Exception as e:
            print(f"\n❌ 실패: {e}")
    elif choice == "3":
        print("종료합니다.")
    else:
        print("잘못된 선택입니다.")


if __name__ == "__main__":
    main()
