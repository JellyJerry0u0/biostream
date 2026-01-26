# ai_service/image/sample_user_data.py
"""
테스트용 샘플 사용자 데이터
다양한 시나리오별 프로필 제공
"""

# 시나리오 1: 고위험 프로필 (노화 촉진 요인 많음)
HIGH_RISK_PROFILE = {
    'age': 35,
    'gender': '남성',
    'smoking': True,           # 흡연
    'drinking': True,          # 음주
    'stress_level': 8,         # 높은 스트레스
    'sleep_hours': 5,          # 수면 부족
    'exercise_frequency': 1,   # 운동 부족
    'uv_exposure': True,       # 자외선 노출
    'sunscreen_use': False,    # 선크림 미사용
}

# 시나리오 2: 건강한 프로필 (노화 촉진 요인 적음)
HEALTHY_PROFILE = {
    'age': 30,
    'gender': '여성',
    'smoking': False,
    'drinking': False,
    'stress_level': 3,
    'sleep_hours': 8,
    'exercise_frequency': 5,
    'uv_exposure': False,
    'sunscreen_use': True,
}

# 시나리오 3: 중간 위험 프로필
MODERATE_RISK_PROFILE = {
    'age': 40,
    'gender': '남성',
    'smoking': False,
    'drinking': True,          # 음주만 함
    'stress_level': 6,
    'sleep_hours': 6.5,
    'exercise_frequency': 2,
    'uv_exposure': True,
    'sunscreen_use': True,     # 선크림은 사용
}

# 시나리오 4: 중년 여성 프로필
MIDDLE_AGED_WOMAN = {
    'age': 45,
    'gender': '여성',
    'smoking': False,
    'drinking': False,
    'stress_level': 7,         # 직장 스트레스
    'sleep_hours': 6,
    'exercise_frequency': 3,
    'uv_exposure': True,
    'sunscreen_use': True,
}

# 시나리오 5: 젊은 흡연자
YOUNG_SMOKER = {
    'age': 28,
    'gender': '남성',
    'smoking': True,           # 흡연이 주요 위험 요인
    'drinking': True,
    'stress_level': 5,
    'sleep_hours': 7,
    'exercise_frequency': 2,
    'uv_exposure': False,
    'sunscreen_use': False,
}

# 기본 테스트용 (고위험 프로필 사용)
DEFAULT_TEST_DATA = HIGH_RISK_PROFILE

# 모든 프로필 목록 (반복 테스트용)
ALL_PROFILES = {
    'high_risk': HIGH_RISK_PROFILE,
    'healthy': HEALTHY_PROFILE,
    'moderate_risk': MODERATE_RISK_PROFILE,
    'middle_aged_woman': MIDDLE_AGED_WOMAN,
    'young_smoker': YOUNG_SMOKER,
}


def get_profile(profile_name: str = 'high_risk') -> dict:
    """
    프로필 이름으로 샘플 데이터 가져오기
    
    Args:
        profile_name: 'high_risk', 'healthy', 'moderate_risk', 
                     'middle_aged_woman', 'young_smoker' 중 하나
    
    Returns:
        사용자 데이터 딕셔너리
    """
    return ALL_PROFILES.get(profile_name, DEFAULT_TEST_DATA).copy()


def print_profile_info(profile_data: dict):
    """프로필 정보 출력"""
    print("\n" + "="*60)
    print("📊 사용자 프로필 정보")
    print("="*60)
    print(f"나이: {profile_data['age']}세")
    print(f"성별: {profile_data['gender']}")
    print(f"흡연: {'예' if profile_data['smoking'] else '아니오'}")
    print(f"음주: {'예' if profile_data['drinking'] else '아니오'}")
    print(f"스트레스: {profile_data['stress_level']}/10")
    print(f"수면: {profile_data['sleep_hours']}시간/일")
    print(f"운동: 주 {profile_data['exercise_frequency']}회")
    print(f"자외선 노출: {'예' if profile_data['uv_exposure'] else '아니오'}")
    print(f"선크림 사용: {'예' if profile_data['sunscreen_use'] else '아니오'}")
    print("="*60 + "\n")


if __name__ == "__main__":
    # 테스트: 모든 프로필 출력
    print("\n🧪 사용 가능한 모든 프로필:\n")
    
    for name, profile in ALL_PROFILES.items():
        print(f"\n[{name}]")
        print_profile_info(profile)
