# ai_service/evaluate_search.py
"""
생활습관별 노화 영향 분석 평가 스크립트
생활습관을 입력받아 노화에 미치는 영향을 분석합니다.
"""

import os
import logging
from test_search import test_search

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# 생활습관별 검색 키워드 매핑 (sample_dataset.json 기반)
LIFESTYLE_KEYWORDS = {
    "흡연": ["흡연", "smoking", "담배"],
    "음주": ["음주", "alcohol", "drinking"],
    "자외선 노출": ["자외선", "선크림", "sunscreen", "uv", "photoaging"],
    "운동": ["운동", "exercise", "physical_activity"],
    "식습관": ["식습관", "diet", "nutrition"],
    "수면": ["수면", "sleep"],
    "스트레스": ["스트레스", "stress"]
}

def analyze_lifestyle_impact(lifestyle: str):
    """
    생활습관의 노화 영향을 분석합니다.
    """
    if lifestyle not in LIFESTYLE_KEYWORDS:
        logger.error(f"지원되지 않는 생활습관: {lifestyle}")
        logger.info(f"지원 생활습관: {', '.join(LIFESTYLE_KEYWORDS.keys())}")
        return

    keywords = LIFESTYLE_KEYWORDS[lifestyle]
    logger.info(f"\n=== {lifestyle}의 노화 영향 분석 ===")

    # 각 키워드로 검색
    all_results = []
    for keyword in keywords:
        logger.info(f"\n'{keyword}' 검색 중...")
        try:
            results = test_search(keyword, limit=5)
            all_results.extend(results)
        except Exception as e:
            logger.error(f"'{keyword}' 검색 실패: {e}")

    if not all_results:
        logger.warning(f"{lifestyle} 관련 데이터를 찾을 수 없습니다.")
        return

    # 결과 분석
    analyze_results(lifestyle, all_results)

def analyze_results(lifestyle: str, results: list):
    """
    검색 결과를 분석하여 생활습관의 노화 영향을 요약합니다.
    """
    logger.info(f"\n=== {lifestyle} 분석 결과 요약 ===")

    # 증거 수준별 분류
    evidence_levels = {"1": [], "2": [], "3": [], "4": [], "5": []}
    effect_directions = {"increase": 0, "decrease": 0, "no_effect": 0, "unknown": 0}

    total_results = len(results)
    relevant_results = 0

    for result in results:
        payload = result.payload

        # 관련성 확인 (topics나 text에 생활습관 키워드 포함)
        text = payload.get('text', '').lower()
        topics = payload.get('topics', '').lower()
        is_relevant = any(keyword.lower() in text or keyword.lower() in topics
                         for keyword in LIFESTYLE_KEYWORDS[lifestyle])

        if is_relevant:
            relevant_results += 1

            # 증거 수준 분류
            evidence_level = str(payload.get('evidence_level', 'unknown'))
            if evidence_level in evidence_levels:
                evidence_levels[evidence_level].append(result)

            # 효과 방향 카운트
            effect_dir = payload.get('effect_direction')
            if effect_dir in effect_directions:
                effect_directions[effect_dir] += 1
            else:
                effect_directions["unknown"] += 1

    # 분석 결과 출력
    logger.info(f"총 검색 결과: {total_results}개")
    logger.info(f"관련 결과: {relevant_results}개 ({relevant_results/total_results*100:.1f}%)")

    if relevant_results > 0:
        logger.info("증거 수준 분포:")
        for level, items in evidence_levels.items():
            if items:
                logger.info(f"  Level {level}: {len(items)}개")

        logger.info("효과 방향:")
        for direction, count in effect_directions.items():
            if count > 0:
                logger.info(f"  {direction}: {count}개")

        # 영향 평가
        evaluate_impact(lifestyle, effect_directions, relevant_results)
    else:
        logger.info(f"{lifestyle}의 노화 영향에 대한 충분한 증거를 찾을 수 없습니다.")

def evaluate_impact(lifestyle: str, effect_directions: dict, total_relevant: int):
    """
    생활습관의 노화 영향을 평가합니다.
    """
    increase = effect_directions.get("increase", 0)
    decrease = effect_directions.get("decrease", 0)

    logger.info(f"\n=== {lifestyle} 노화 영향 평가 ===")

    if increase > decrease:
        impact = "노화 촉진"
        confidence = (increase - decrease) / total_relevant
    elif decrease > increase:
        impact = "노화 억제"
        confidence = (decrease - increase) / total_relevant
    else:
        impact = "불명확"
        confidence = 0

    logger.info(f"예상 영향: {impact}")
    logger.info(f"신뢰도: {confidence:.2f} (증거 기반)")

    # 권장사항
    if impact == "노화 촉진":
        logger.info(f"💡 {lifestyle}을(를) 줄이는 것이 노화 예방에 도움이 될 수 있습니다.")
    elif impact == "노화 억제":
        logger.info(f"💡 {lifestyle}을(를) 유지/증가시키는 것이 노화 예방에 도움이 될 수 있습니다.")
    else:
        logger.info(f"💡 {lifestyle}의 노화 영향에 대한 추가 연구가 필요합니다.")

def interactive_lifestyle_analysis():
    """
    대화형 생활습관 분석 모드
    """
    print("생활습관 노화 영향 분석 모드")
    print("분석할 생활습관을 입력하세요 (종료: exit)")
    print(f"지원 생활습관: {', '.join(LIFESTYLE_KEYWORDS.keys())}")
    print("-" * 50)

    while True:
        lifestyle = input("생활습관: ").strip()
        if lifestyle.lower() in ['exit', 'quit', 'q']:
            print("분석을 종료합니다.")
            break

        if lifestyle in LIFESTYLE_KEYWORDS:
            try:
                analyze_lifestyle_impact(lifestyle)
            except Exception as e:
                print(f"분석 중 오류: {e}")
        else:
            print(f"지원되지 않는 생활습관입니다. 지원 목록: {', '.join(LIFESTYLE_KEYWORDS.keys())}")

        print("-" * 50)

if __name__ == "__main__":
    import sys

    if len(sys.argv) == 1:
        # 인자가 없으면 대화형 모드
        interactive_lifestyle_analysis()
    elif len(sys.argv) == 2:
        # 생활습관 하나 입력
        lifestyle = sys.argv[1]
        analyze_lifestyle_impact(lifestyle)
    else:
        print("사용법:")
        print("  python evaluate_search.py                    # 대화형 모드")
        print("  python evaluate_search.py '흡연'            # 특정 생활습관 분석")
        sys.exit(1)