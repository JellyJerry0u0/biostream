#!/usr/bin/env python3
"""
리포트 생성 스모크 테스트
"""

import sys
import os
import json
from pathlib import Path

# 경로 설정
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

from langgraph_modules.report_graph import generate_report

def test_report_generation(user_id: int = 1):
    """리포트 생성 테스트"""
    print("="*80)
    print("리포트 생성 스모크 테스트")
    print("="*80)
    print(f"user_id: {user_id}")
    print()
    
    try:
        result = generate_report(user_id=user_id, lifestyle_id=None)
        
        if not result.get("success"):
            print(f"❌ 리포트 생성 실패: {result.get('error')}")
            return False
        
        report = result.get("report", {})
        
        # 검증
        print("\n[검증 시작]")
        
        # 1. tabs 확인
        tabs = report.get("tabs", [])
        print(f"✅ tabs: {tabs}")
        assert isinstance(tabs, list), "tabs는 리스트여야 합니다"
        
        # 2. sections 확인
        sections = report.get("sections", {})
        print(f"✅ sections: {list(sections.keys())}")
        assert isinstance(sections, dict), "sections는 딕셔너리여야 합니다"
        
        # 3. 각 섹션의 4카드 확인
        for section_name, section_data in sections.items():
            print(f"\n  [{section_name}] 검증:")
            cards = section_data.get("cards", [])
            print(f"    카드 수: {len(cards)}")
            assert len(cards) == 4, f"{section_name} 섹션은 4개의 카드를 가져야 합니다"
            
            # 카드 타입 확인
            card_types = [card.get("type") for card in cards]
            expected_types = ["problem", "cause", "action", "simulation"]
            print(f"    카드 타입: {card_types}")
            assert set(card_types) == set(expected_types), f"{section_name} 섹션의 카드 타입이 올바르지 않습니다"
            
            # action 카드 items 확인
            action_card = next((c for c in cards if c.get("type") == "action"), None)
            if action_card:
                items = action_card.get("items", [])
                print(f"    action.items 수: {len(items)}")
                assert len(items) == 3, f"{section_name} 섹션의 action.items는 정확히 3개여야 합니다"
            
            # simulation 카드 meta 확인
            simulation_card = next((c for c in cards if c.get("type") == "simulation"), None)
            if simulation_card:
                meta = simulation_card.get("meta", {})
                mode = meta.get("mode")
                print(f"    simulation.mode: {mode}")
                assert mode in ["grounded", "estimated"], f"simulation.mode는 'grounded' 또는 'estimated'여야 합니다"
                
                if mode == "estimated":
                    disclaimer = meta.get("disclaimer_small", "")
                    print(f"    disclaimer: {disclaimer[:50]}...")
                    assert disclaimer, "estimated 모드일 때 disclaimer_small이 필수입니다"
            
            # 문장 수 제한 확인
            import re
            problem_card = next((c for c in cards if c.get("type") == "problem"), None)
            cause_card = next((c for c in cards if c.get("type") == "cause"), None)
            
            if problem_card:
                problem_text = problem_card.get("text", "")
                problem_sentences = len(re.split(r'[.!?。！？]\s*', problem_text))
                print(f"    problem 문장 수: {problem_sentences}")
                assert problem_sentences <= 3, f"{section_name} 섹션의 problem은 3문장 이하여야 합니다"
            
            if cause_card:
                cause_text = cause_card.get("text", "")
                cause_sentences = len(re.split(r'[.!?。！？]\s*', cause_text))
                print(f"    cause 문장 수: {cause_sentences}")
                assert cause_sentences <= 3, f"{section_name} 섹션의 cause는 3문장 이하여야 합니다"
            
            if simulation_card:
                simulation_text = simulation_card.get("text", "")
                simulation_sentences = len(re.split(r'[.!?。！？]\s*', simulation_text))
                print(f"    simulation 문장 수: {simulation_sentences}")
                assert simulation_sentences <= 4, f"{section_name} 섹션의 simulation은 4문장 이하여야 합니다"
                
                # 개인화 검증: "당신의", "현재", 또는 설문 값 포함 확인
                has_personalization = (
                    "당신의" in simulation_text or
                    "당신은" in simulation_text or
                    "현재" in simulation_text or
                    any(char.isdigit() for char in simulation_text)  # 숫자 포함 (시간, 횟수, 점수 등)
                )
                print(f"    simulation 개인화 여부: {has_personalization}")
                assert has_personalization, f"{section_name} 섹션의 simulation은 개인화된 문장을 포함해야 합니다 (당신의/당신은/현재 또는 설문 값)"
            
            # evidence_refs 확인
            evidence_refs = section_data.get("evidence_refs", {})
            narrative_refs = evidence_refs.get("narrative", [])
            quant_refs = evidence_refs.get("quant", [])
            print(f"    narrative refs: {len(narrative_refs)}개")
            print(f"    quant refs: {len(quant_refs)}개")
            
            # grounded일 때 quant_refs 확인
            if simulation_card and simulation_card.get("meta", {}).get("mode") == "grounded":
                assert len(quant_refs) > 0, "grounded 모드일 때 quant_refs가 있어야 합니다"
        
        # 4. 본문에 PMC/PMID/p= 패턴 노출 확인
        report_str = json.dumps(report, ensure_ascii=False)
        citation_patterns = [
            (r'PMC\d+', 'PMC'),
            (r'PMID\s*:?\s*\d+', 'PMID'),
            (r'p\s*[=<>]\s*[\d.]+', 'p='),
            (r'CI\s*:?\s*\[[^\]]+\]', 'CI'),
        ]
        
        found_patterns = []
        for pattern, name in citation_patterns:
            if re.search(pattern, report_str, re.IGNORECASE):
                found_patterns.append(name)
        
        if found_patterns:
            print(f"\n❌ 본문에 논문 정보 노출 발견: {', '.join(found_patterns)}")
            assert False, f"본문에 논문 정보({', '.join(found_patterns)})가 노출되어서는 안 됩니다"
        else:
            print("\n✅ 본문에 PMC/PMID/p=/CI 노출 없음")
        
        print("\n" + "="*80)
        print("✅ 모든 검증 통과!")
        print("="*80)
        return True
        
    except AssertionError as e:
        print(f"\n❌ 검증 실패: {e}")
        return False
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--user_id", type=int, default=1, help="테스트할 user_id")
    args = parser.parse_args()
    
    success = test_report_generation(user_id=args.user_id)
    sys.exit(0 if success else 1)
