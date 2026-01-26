# ai_service/test_pipeline.py
"""
BioStream 파이프라인 테스트 스크립트
"""

import sys
import os
from pathlib import Path
from ai_service.image.biostream_pipeline import BioStreamPipeline

def test_basic_pipeline():
    """기본 파이프라인 테스트"""
    
    print("=" * 70)
    print("BioStream 파이프라인 테스트")
    print("=" * 70)
    
    # 샘플 사용자 데이터 - 노화 위험 요인이 많은 케이스
    user_data = {
        'age': 40,
        'gender': '남성',
        'smoking': True,          # 흡연자
        'drinking': True,         # 음주
        'stress_level': 9,        # 높은 스트레스
        'sleep_hours': 5,         # 수면 부족
        'exercise_frequency': 1   # 운동 부족
    }
    
    print("\n[사용자 정보]")
    print(f"나이: {user_data['age']}세")
    print(f"성별: {user_data['gender']}")
    print(f"흡연: {'예' if user_data['smoking'] else '아니오'}")
    print(f"음주: {'예' if user_data['drinking'] else '아니오'}")
    print(f"스트레스: {user_data['stress_level']}/10")
    print(f"수면: {user_data['sleep_hours']}시간")
    print(f"운동: 주 {user_data['exercise_frequency']}회")
    
    # 테스트 이미지 경로 입력
    print("\n" + "-" * 70)
    image_path = input("테스트할 이미지 경로를 입력하세요 (예: C:/Users/.../photo.jpg): ").strip()
    
    # 경로 검증
    if not os.path.exists(image_path):
        print(f"❌ 오류: 이미지 파일을 찾을 수 없습니다: {image_path}")
        return
    
    try:
        # 파이프라인 초기화 및 실행
        print("\n파이프라인 초기화 중...")
        pipeline = BioStreamPipeline()
        
        print("파이프라인 실행 중... (1-2분 소요될 수 있습니다)")
        result = pipeline.run(user_data, image_path)
        
        # 결과 출력
        print("\n" + "=" * 70)
        print("✅ 파이프라인 실행 완료!")
        print("=" * 70)
        
        print("\n" + "-" * 70)
        print("[생성된 이미지 URL]")
        print("-" * 70)
        print(result['image_url'])
        
        print("\n" + "-" * 70)
        print("[한글 분석 리포트]")
        print("-" * 70)
        print(result['korean_report'])
        
        print("\n" + "-" * 70)
        print("[사용된 영문 프롬프트]")
        print("-" * 70)
        print(result['raw_prompt'])
        
        print("\n" + "-" * 70)
        print("[논문 근거 요약]")
        print("-" * 70)
        for evidence in result['evidence']:
            print(f"[{evidence['rank']}] 유사도: {evidence['score']:.4f} | "
                  f"근거 수준: {evidence['evidence_level']} | "
                  f"논문 ID: {evidence['paper_id']}")
        
        print("\n" + "=" * 70)
        print("테스트 완료!")
        print("=" * 70)
        
    except Exception as e:
        print(f"\n❌ 오류 발생: {str(e)}")
        import traceback
        traceback.print_exc()


def test_multiple_scenarios():
    """다양한 시나리오 테스트"""
    
    scenarios = [
        {
            'name': '건강한 30대',
            'data': {
                'age': 30,
                'gender': '여성',
                'smoking': False,
                'drinking': False,
                'stress_level': 3,
                'sleep_hours': 8,
                'exercise_frequency': 5
            }
        },
        {
            'name': '고위험 40대',
            'data': {
                'age': 45,
                'gender': '남성',
                'smoking': True,
                'drinking': True,
                'stress_level': 9,
                'sleep_hours': 5,
                'exercise_frequency': 0
            }
        },
        {
            'name': '중간 위험 50대',
            'data': {
                'age': 50,
                'gender': '여성',
                'smoking': False,
                'drinking': True,
                'stress_level': 6,
                'sleep_hours': 6,
                'exercise_frequency': 2
            }
        }
    ]
    
    print("=" * 70)
    print("BioStream 파이프라인 - 다중 시나리오 테스트")
    print("=" * 70)
    
    for i, scenario in enumerate(scenarios, 1):
        print(f"\n[시나리오 {i}] {scenario['name']}")
        print("-" * 70)
        
        # 시나리오별 사용자 데이터 출력
        data = scenario['data']
        print(f"나이: {data['age']}세 / 성별: {data['gender']}")
        print(f"흡연: {'예' if data['smoking'] else '아니오'} / "
              f"음주: {'예' if data['drinking'] else '아니오'}")
        print(f"스트레스: {data['stress_level']}/10 / "
              f"수면: {data['sleep_hours']}시간 / "
              f"운동: 주 {data['exercise_frequency']}회")
        
        # 이 부분은 실제 이미지 경로가 필요하므로 주석 처리
        # pipeline = BioStreamPipeline()
        # result = pipeline.run(data, image_path)
        print("(실제 실행은 이미지 경로 제공 시 가능)")


def main():
    """메인 함수"""
    print("\nBioStream 파이프라인 테스트 도구\n")
    print("1. 기본 테스트 (단일 이미지)")
    print("2. 시나리오 미리보기")
    print("3. 종료")
    
    choice = input("\n선택하세요 (1-3): ").strip()
    
    if choice == '1':
        test_basic_pipeline()
    elif choice == '2':
        test_multiple_scenarios()
    elif choice == '3':
        print("종료합니다.")
    else:
        print("잘못된 선택입니다.")


if __name__ == "__main__":
    main()
