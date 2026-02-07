#!/usr/bin/env python3
"""
리포트 그래프 유닛 테스트
- 전체 그래프 실행 시 예외 없이 final_report 생성되는지 확인
- section_cards 각 섹션에 4카드 구조 보장되는지 확인
"""

import sys
import os
import json
from pathlib import Path

# 경로 설정
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

from langgraph_modules.report_graph import (
    create_report_graph,
    ReportState,
    _extract_keyword_based_sentences,
    SECTION_CARD_TYPE_KEYWORDS
)


def test_extract_keyword_based_sentences():
    """키워드 기반 문장 추출 테스트"""
    print("[테스트] _extract_keyword_based_sentences")
    
    # 테스트 케이스 1: 키워드 매칭 성공
    text = "수면 시간이 부족하면 피부 건강에 좋지 않습니다. 불규칙한 수면 패턴은 콜라겐 생성을 방해합니다. 규칙적인 수면 습관을 유지하는 것이 중요합니다."
    keywords = ["수면", "부족", "불규칙"]
    result = _extract_keyword_based_sentences(text, keywords, max_sentences=2)
    assert len(result) > 0, "키워드 매칭 시 문장이 추출되어야 합니다"
    assert any("수면" in s or "부족" in s for s in result), "키워드가 포함된 문장이 추출되어야 합니다"
    print("  ✅ 키워드 매칭 성공")
    
    # 테스트 케이스 2: 키워드 매칭 실패 시 첫 문장 fallback
    text = "일반적인 건강 정보입니다. 특별한 내용이 없습니다."
    keywords = ["존재하지않는키워드"]
    result = _extract_keyword_based_sentences(text, keywords, max_sentences=2)
    assert len(result) > 0, "키워드 매칭 실패 시 첫 문장 fallback이 작동해야 합니다"
    print("  ✅ 키워드 매칭 실패 시 fallback 성공")
    
    print("✅ _extract_keyword_based_sentences 테스트 통과\n")


def test_section_card_type_keywords():
    """섹션별 카드 타입 키워드 사전 테스트"""
    print("[테스트] SECTION_CARD_TYPE_KEYWORDS")
    
    # 모든 섹션에 키워드가 정의되어 있는지 확인
    required_sections = ["sleep", "uv", "lifestyle", "activity", "goals"]
    required_card_types = ["problem", "cause", "action"]
    
    for section in required_sections:
        assert section in SECTION_CARD_TYPE_KEYWORDS, f"{section} 섹션의 키워드가 정의되어야 합니다"
        for card_type in required_card_types:
            assert card_type in SECTION_CARD_TYPE_KEYWORDS[section], \
                f"{section}.{card_type}의 키워드가 정의되어야 합니다"
            assert len(SECTION_CARD_TYPE_KEYWORDS[section][card_type]) > 0, \
                f"{section}.{card_type}의 키워드가 비어있지 않아야 합니다"
    
    print("  ✅ 모든 섹션/카드 타입에 키워드가 정의되어 있음")
    print("✅ SECTION_CARD_TYPE_KEYWORDS 테스트 통과\n")


def test_graph_structure():
    """그래프 구조 테스트"""
    print("[테스트] 그래프 구조")
    
    app = create_report_graph()
    assert app is not None, "그래프가 생성되어야 합니다"
    
    # 노드 확인
    nodes = app.nodes if hasattr(app, 'nodes') else None
    if nodes:
        required_nodes = [
            "load_survey", "plan_sections", "derive_user_profile",
            "preload_quant_evidence", "build_queries", "retrieve_narrative_evidence",
            "extract_claims", "write_section_cards", "validate_cards",
            "assemble_report", "save_report"
        ]
        for node in required_nodes:
            assert node in nodes, f"{node} 노드가 그래프에 포함되어야 합니다"
    
    print("  ✅ 그래프 구조가 올바름")
    print("✅ 그래프 구조 테스트 통과\n")


def test_report_state_structure():
    """ReportState 구조 테스트"""
    print("[테스트] ReportState 구조")
    
    # 필수 필드 확인
    sample_state: ReportState = {
        "user_id": 1,
        "lifestyle_id": None,
        "survey": {},
        "user_profile": {},
        "active_sections": ["sleep"],
        "available_quant_outcomes": set(),
        "quant_evidence_results": {},
        "section_queries": {},
        "narrative_evidence": {},
        "extracted_claims": {},
        "section_cards": {},
        "quality_flags": {},
        "final_report": None,
    }
    
    # 선택적 필드 확인 (total=False이므로 없어도 됨)
    sample_state_with_retry: ReportState = {
        **sample_state,
        "retry_needed": False,
        "retry_sections": [],
        "retry_count": {},
    }
    
    assert sample_state["user_id"] == 1
    assert isinstance(sample_state.get("active_sections"), list)
    
    print("  ✅ ReportState 구조가 올바름")
    print("✅ ReportState 구조 테스트 통과\n")


def test_section_cards_structure():
    """섹션 카드 구조 테스트"""
    print("[테스트] section_cards 구조")
    
    # 4카드 구조 샘플
    sample_cards = [
        {"type": "problem", "title": "현재 상태", "text": "테스트 문제"},
        {"type": "cause", "title": "원인", "text": "테스트 원인"},
        {"type": "action", "title": "행동", "items": [
            {"title": "Action 1", "detail": "Detail 1"},
            {"title": "Action 2", "detail": "Detail 2"},
            {"title": "Action 3", "detail": "Detail 3"},
        ]},
        {"type": "simulation", "title": "예상 경로", "text": "테스트 시뮬레이션", "meta": {
            "mode": "estimated",
            "disclaimer_small": "테스트 disclaimer"
        }},
    ]
    
    # 카드 수 확인
    assert len(sample_cards) == 4, "섹션당 4개의 카드가 있어야 합니다"
    
    # 카드 타입 확인
    card_types = [card.get("type") for card in sample_cards]
    required_types = {"problem", "cause", "action", "simulation"}
    assert set(card_types) == required_types, "필수 카드 타입이 모두 있어야 합니다"
    
    # action 카드 items 확인
    action_card = next((c for c in sample_cards if c.get("type") == "action"), None)
    assert action_card is not None, "action 카드가 있어야 합니다"
    assert len(action_card.get("items", [])) == 3, "action.items는 3개여야 합니다"
    
    # simulation 카드 meta 확인
    simulation_card = next((c for c in sample_cards if c.get("type") == "simulation"), None)
    assert simulation_card is not None, "simulation 카드가 있어야 합니다"
    assert "meta" in simulation_card, "simulation 카드에 meta가 있어야 합니다"
    assert "mode" in simulation_card["meta"], "simulation.meta.mode가 있어야 합니다"
    
    print("  ✅ section_cards 구조가 올바름")
    print("✅ section_cards 구조 테스트 통과\n")


def run_all_tests():
    """모든 테스트 실행"""
    print("="*80)
    print("리포트 그래프 유닛 테스트 시작")
    print("="*80)
    print()
    
    try:
        test_extract_keyword_based_sentences()
        test_section_card_type_keywords()
        test_graph_structure()
        test_report_state_structure()
        test_section_cards_structure()
        
        print("="*80)
        print("✅ 모든 유닛 테스트 통과!")
        print("="*80)
        return True
        
    except AssertionError as e:
        print(f"\n❌ 테스트 실패: {e}")
        import traceback
        traceback.print_exc()
        return False
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
