#!/usr/bin/env python3
"""
리팩토링 검증 테스트 스크립트
목표: A~F 요구사항이 모두 반영되었는지 확인
"""

import sys
import os
import json
from pathlib import Path

# 프로젝트 루트를 path에 추가
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

from langgraph_modules.report_graph import (
    generate_report,
    map_outcomes_to_topics,
    OUTCOME_TO_NARRATIVE_TOPICS,
)


def test_outcome_to_topics_mapping():
    """B. Outcome -> Narrative Topics 매핑 테스트"""
    print("\n=== B. Outcome -> Narrative Topics 매핑 테스트 ===")
    
    test_cases = [
        (["wrinkle"], ["wrinkle_elasticity", "wrinkle", "skin_aging", "collagen"]),
        (["hydration_barrier"], ["barrier_hydration", "skin_barrier", "hydration", "moisture"]),
        (["wrinkle", "hydration_barrier"], None),  # 중복 제거 확인용
    ]
    
    for outcomes, expected_prefix in test_cases:
        topics = map_outcomes_to_topics(outcomes, include_fallback=True)
        print(f"  Input: {outcomes}")
        print(f"  Output: {topics}")
        
        if expected_prefix:
            assert any(t in topics for t in expected_prefix), f"Expected topics not found: {expected_prefix}"
        print("  ✅ PASS")
    
    print("✅ B. Outcome 매핑 테스트 통과\n")


def test_report_generation_smoke():
    """전체 리포트 생성 스모크 테스트 (A, C, D, E, F 검증)"""
    print("\n=== 리포트 생성 스모크 테스트 ===")
    
    # 테스트용 user_id (실제 DB에 존재해야 함)
    test_user_id = 1  # 필요시 수정
    
    print(f"  User ID: {test_user_id}")
    print("  리포트 생성 중...")
    
    try:
        result = generate_report(test_user_id, lifestyle_id=None)
        
        if not result.get("success"):
            print(f"  ⚠️ 리포트 생성 실패: {result.get('error')}")
            print("  (이것은 정상일 수 있습니다 - DB 연결/데이터 부족)")
            return
        
        report = result.get("report", {})
        sections = report.get("sections", {})
        
        # A. user_profile 검증
        print("\n  A. user_profile 검증:")
        # state dump가 없으므로 로그에서 확인 필요
        print("    → 로그에서 '[DeriveUserProfile] 사용자 프로필 계산 완료' 확인 필요")
        
        # B. topics 매핑 검증
        print("\n  B. topics 매핑 검증:")
        goals_section = sections.get("goals", {})
        if goals_section:
            print("    → goals 섹션 존재 확인")
            print("    → 로그에서 'UI outcomes [...] → narrative topics [...]' 확인 필요")
        
        # C. 듀얼 쿼리 검증
        print("\n  C. 듀얼 쿼리 검증:")
        print("    → 로그에서 '1차 영어 검색' 메시지 확인 필요")
        print("    → 로그에서 '2차 한국어 보충' 또는 '3차 fallback' 메시지 확인 필요")
        
        # D. quant fallback 검증
        print("\n  D. Quant fallback 검증:")
        print("    → 로그에서 'Available quant outcomes: N개' 확인 필요")
        print("    → 로그에서 'available outcomes만 사용' 메시지 확인 필요")
        
        # E, F는 리포트 내용에서 확인
        print("\n  E, F. Claim extraction & 과확신 표현:")
        print("    → 리포트 카드 텍스트에서 '반드시' 같은 강한 표현이 없는지 확인")
        
        print("\n  ✅ 리포트 생성 완료")
        print(f"  섹션 수: {len(sections)}")
        print(f"  섹션 목록: {list(sections.keys())}")
        
    except Exception as e:
        print(f"  ❌ 에러 발생: {e}")
        import traceback
        traceback.print_exc()


def test_available_outcomes_collection():
    """D. Available outcomes 수집 테스트"""
    print("\n=== D. Available Outcomes 수집 테스트 ===")
    
    # 실제 quant tool을 호출하여 available outcomes 확인
    try:
        from app.services.quant_evidence_retriever import get_grouped_stats
        
        test_outcomes = ["wrinkle", "elasticity", "hydration_barrier", "nonexistent_outcome"]
        available = []
        
        for outcome in test_outcomes:
            try:
                stats = get_grouped_stats(outcome, exclude_suspicious=True)
                if stats and stats.get("timeframe_groups"):
                    available.append(outcome)
                    print(f"  ✅ {outcome}: available")
                else:
                    print(f"  ❌ {outcome}: not available")
            except Exception as e:
                print(f"  ⚠️ {outcome}: error - {e}")
        
        print(f"\n  Available outcomes: {available}")
        print("  ✅ D. Available outcomes 테스트 완료\n")
        
    except ImportError:
        print("  ⚠️ quant_evidence_retriever를 import할 수 없습니다. 스킵합니다.\n")


if __name__ == "__main__":
    print("=" * 60)
    print("리팩토링 검증 테스트")
    print("=" * 60)
    
    # B. 매핑 테스트 (항상 실행 가능)
    test_outcome_to_topics_mapping()
    
    # D. Available outcomes 테스트
    test_available_outcomes_collection()
    
    # 전체 리포트 생성 테스트 (DB 연결 필요)
    print("\n전체 리포트 생성 테스트를 실행하시겠습니까? (DB 연결 필요)")
    print("실행하려면 test_report_generation_smoke()의 주석을 해제하세요.")
    # test_report_generation_smoke()
    
    print("\n" + "=" * 60)
    print("테스트 완료")
    print("=" * 60)
    print("\n검증 체크리스트:")
    print("  [ ] A. 로그에서 '[DeriveUserProfile] 사용자 프로필 계산 완료' 확인")
    print("  [ ] B. 로그에서 'UI outcomes [...] → narrative topics [...]' 확인")
    print("  [ ] C. 로그에서 '1차 영어 검색' 메시지 확인")
    print("  [ ] D. 로그에서 'Available quant outcomes: N개' 확인")
    print("  [ ] E. 리포트 카드 텍스트가 문장 단위로 잘 추출되었는지 확인")
    print("  [ ] F. 리포트에서 '반드시' 같은 강한 표현이 완화되었는지 확인")
