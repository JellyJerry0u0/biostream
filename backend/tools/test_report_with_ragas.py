"""
LangGraph 리포트 생성 + RAGAS 신뢰도 평가 통합 테스트

실제 사용자 데이터로 리포트를 생성하고, 생성된 리포트의 신뢰도를 RAGAS로 평가합니다.
"""

import os
import sys
from dotenv import load_dotenv

load_dotenv()

# 경로 설정
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(backend_dir)

print("\n" + "="*70)
print("LangGraph 리포트 생성 + RAGAS 신뢰도 평가 통합 테스트")
print("="*70 + "\n")

# 1. LangGraph 리포트 생성
print("1️⃣ LangGraph로 리포트 생성 중...")
print("-" * 70)

from langgraph_modules.report_graph import create_report_graph

# LangGraph app 생성
app = create_report_graph()

# 테스트용 초기 State
initial_state = {
    "user_id": 1,
    "lifestyle_id": 1,
    "survey": None,
    "user_profile": None,
    "active_sections": [],
    "available_quant_outcomes": None,
    "quant_evidence_results": {},
    "section_queries": {},
    "narrative_evidence": {},
    "section_cards": {},
    "quality_flags": {},
    "final_report": None
}

try:
    print("   LangGraph 실행 중... (수 분 소요될 수 있습니다)")
    config = {"configurable": {"thread_id": "test_user_1"}}
    final_state = app.invoke(initial_state, config)
    print("✅ 리포트 생성 완료!\n")
    
    # 생성된 섹션 확인
    active_sections = final_state.get("active_sections", [])
    print(f"   생성된 섹션: {active_sections}")
    
    # 각 섹션의 카드 개수 확인
    section_cards = final_state.get("section_cards", {})
    for section in active_sections:
        cards = section_cards.get(section, [])
        print(f"   [{section}]: {len(cards)}개 카드")
    
except Exception as e:
    print(f"❌ 리포트 생성 실패: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

# 2. RAGAS 신뢰도 평가
print("\n" + "="*70)
print("2️⃣ RAGAS 신뢰도 평가 실행 중...")
print("-" * 70 + "\n")

from tools.reliability_auditor import ReliabilityAuditor

try:
    auditor = ReliabilityAuditor()
    scores = auditor.evaluate_report_state(final_state)
    
    print("\n" + "="*70)
    print("3️⃣ 평가 결과")
    print("="*70 + "\n")
    
    # 섹션별 결과 출력
    for section, section_scores in scores.items():
        print(f"📊 [{section.upper()}] 섹션")
        print("-" * 70)
        
        for score in section_scores:
            grade_emoji = "✅" if score.grade == "Verified" else "🔵" if score.grade == "Plausible" else "⚠️"
            
            print(f"\n  {grade_emoji} {score.card_type.upper()} 카드:")
            print(f"     등급: {score.grade} ({score.color})")
            print(f"     Faithfulness: {score.faithfulness_score:.3f}")
            print(f"     Relevancy:    {score.relevancy_score:.3f}")
            print(f"     평균 점수:    {score.average_score:.3f}")
            print(f"     메시지: \"{score.message}\"")
            print(f"     근거 문서: {score.contexts_count}개")
            print(f"     답변 길이: {score.answer_length}자")
        
        print("\n" + "-" * 70 + "\n")
    
    # 전체 통계
    print("="*70)
    print("📈 전체 통계")
    print("="*70 + "\n")
    
    total_cards = sum(len(section_scores) for section_scores in scores.values())
    all_scores_list = [score for section_scores in scores.values() for score in section_scores]
    
    if all_scores_list:
        avg_faithfulness = sum(s.faithfulness_score for s in all_scores_list) / len(all_scores_list)
        avg_relevancy = sum(s.relevancy_score for s in all_scores_list) / len(all_scores_list)
        avg_overall = sum(s.average_score for s in all_scores_list) / len(all_scores_list)
        
        grade_counts = {"Verified": 0, "Plausible": 0, "Caution": 0}
        for score in all_scores_list:
            grade_counts[score.grade] += 1
        
        print(f"  총 평가 카드 수: {total_cards}개")
        print(f"\n  평균 점수:")
        print(f"    Faithfulness: {avg_faithfulness:.3f}")
        print(f"    Relevancy:    {avg_relevancy:.3f}")
        print(f"    Overall:      {avg_overall:.3f}")
        print(f"\n  등급 분포:")
        print(f"    ✅ Verified:  {grade_counts['Verified']}개 ({grade_counts['Verified']/total_cards*100:.1f}%)")
        print(f"    🔵 Plausible: {grade_counts['Plausible']}개 ({grade_counts['Plausible']/total_cards*100:.1f}%)")
        print(f"    ⚠️ Caution:   {grade_counts['Caution']}개 ({grade_counts['Caution']/total_cards*100:.1f}%)")
        
        # 전체 등급 결정
        if avg_overall >= 0.9:
            overall_grade = "Verified (Green)"
        elif avg_overall >= 0.7:
            overall_grade = "Plausible (Blue)"
        else:
            overall_grade = "Caution (Yellow)"
        
        print(f"\n  📊 전체 리포트 등급: {overall_grade}")
        print("\n" + "="*70)
        print("✅ 평가 완료!")
        print("="*70 + "\n")
    else:
        print("⚠️ 평가 결과가 없습니다.")
    
except Exception as e:
    print(f"\n❌ RAGAS 평가 실패: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
