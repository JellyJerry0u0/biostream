"""
RAGAS 기반 리포트 신뢰도 평가 도구

LangGraph로 생성된 리포트의 신뢰도를 RAGAS의 faithfulness와 answer_relevancy 지표로 측정하고,
점수에 따라 Verified/Plausible/Caution 등급을 부여합니다.

신뢰도 등급:
- Score ≥ 0.9: Verified (Green) - "모든 내용이 논문 근거와 일치합니다."
- 0.7 ≤ Score < 0.9: Plausible (Blue) - "대부분의 근거가 확실하며 개연성이 높습니다."
- Score < 0.7: Caution (Yellow) - "일부 추론이 포함되어 있으니 주의가 필요합니다."
"""

import os
import sys
from typing import Dict, Any, List, Optional
from dataclasses import dataclass
import pandas as pd
from dotenv import load_dotenv

# 환경변수 로드
load_dotenv()

# RAGAS 및 LangChain 임포트
try:
    from ragas import evaluate
    from ragas.metrics import faithfulness, answer_relevancy
    from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
    from datasets import Dataset
except ImportError as e:
    print(f" 필수 패키지 임포트 실패: {e}")
    print("다음 명령어로 설치하세요: pip install ragas langchain-google-genai datasets")
    sys.exit(1)


# 상대 경로 설정 (tools 디렉토리에서 backend 디렉토리 접근)
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(backend_dir)

from tools.schemas import EvidenceItem


@dataclass
class ReliabilityScore:
    """신뢰도 평가 결과"""
    section: str
    card_type: str
    faithfulness_score: float
    relevancy_score: float
    average_score: float
    grade: str  # "Verified", "Plausible", "Caution"
    color: str  # "Green", "Blue", "Yellow"
    message: str
    question: str
    contexts_count: int
    answer_length: int


class ReliabilityAuditor:
    """RAGAS 기반 신뢰도 평가기"""
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Args:
            api_key: Google API Key (없으면 환경변수에서 자동 로드)
        """
        self.api_key = api_key or os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY 또는 GOOGLE_API_KEY 환경변수를 설정해주세요.")
        
        # Gemini 2.0 Flash 평가용 LLM 설정 (RAGAS 0.4.x 호환)
        self.evaluator_llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash",
            temperature=0.0,  # 평가는 일관성이 중요하므로 temperature=0
            google_api_key=self.api_key
        )
        
        # Google Embeddings 설정 (answer_relevancy에 필요)
        self.evaluator_embeddings = GoogleGenerativeAIEmbeddings(
            model="models/gemini-embedding-001",
            google_api_key=self.api_key
        )
        
        print("✅ ReliabilityAuditor 초기화 완료 (모델: gemini-2.0-flash)")
    
    def _calculate_grade(self, score: float) -> tuple[str, str, str]:
        """점수에 따른 등급, 색상, 메시지 반환"""
        if score >= 0.9:
            return "Verified", "Green", "모든 내용이 논문 근거와 일치합니다."
        elif score >= 0.7:
            return "Plausible", "Blue", "대부분의 근거가 확실하며 개연성이 높습니다."
        else:
            return "Caution", "Yellow", "일부 추론이 포함되어 있으니 주의가 필요합니다."
    
    def evaluate_section(
        self,
        section: str,
        card_type: str,
        question: str,
        contexts: List[str],
        answer: str
    ) -> Optional[ReliabilityScore]:
        """단일 섹션-카드 조합의 신뢰도 평가
        
        Args:
            section: 섹션 이름 (예: "sleep", "uv")
            card_type: 카드 타입 (예: "problem", "cause", "action")
            question: 질문 (쿼리)
            contexts: 근거 텍스트 리스트
            answer: 생성된 답변 (카드 텍스트)
        
        Returns:
            ReliabilityScore 객체 (평가 실패 시 None)
        """
        # 데이터 검증
        if not contexts or not answer or not question:
            print(f"⚠️ [{section}/{card_type}] 데이터 부족으로 평가 건너뜀")
            return None
        
        try:
            # RAGAS 데이터셋 형식으로 변환
            eval_data = {
                "question": [question],
                "contexts": [contexts],
                "answer": [answer]
            }
            dataset = Dataset.from_dict(eval_data)
            
            # RAGAS 평가 실행 (RAGAS 0.4.x API)
            print(f"  🔍 [{section}/{card_type}] RAGAS 평가 실행 중...")
            result = evaluate(
                dataset,
                metrics=[faithfulness, answer_relevancy],
                llm=self.evaluator_llm,
                embeddings=self.evaluator_embeddings  # Google Embeddings 전달
            )
            
            # 디버그: 결과 구조 확인
            print(f"  [DEBUG] 결과 타입: {type(result)}")
            print(f"  [DEBUG] 결과 키: {result.keys() if hasattr(result, 'keys') else 'No keys'}")
            print(f"  [DEBUG] 결과 컬럼: {result.columns.tolist() if hasattr(result, 'columns') else 'No columns'}")
            
            # 점수 추출 (RAGAS 0.4.x는 DataFrame 형태 반환)
            faithfulness_score = result["faithfulness"].iloc[0] if "faithfulness" in result.columns else 0.0
            relevancy_score = result["answer_relevancy"].iloc[0] if "answer_relevancy" in result.columns else 0.0
            average_score = (faithfulness_score + relevancy_score) / 2
            
            # 등급 계산
            grade, color, message = self._calculate_grade(average_score)
            
            # 결과 객체 생성
            score = ReliabilityScore(
                section=section,
                card_type=card_type,
                faithfulness_score=faithfulness_score,
                relevancy_score=relevancy_score,
                average_score=average_score,
                grade=grade,
                color=color,
                message=message,
                question=question,
                contexts_count=len(contexts),
                answer_length=len(answer)
            )
            
            print(f"  ✅ [{section}/{card_type}] 평가 완료 - {grade} ({average_score:.3f})")
            return score
            
        except Exception as e:
            print(f"  ❌ [{section}/{card_type}] 평가 실패: {e}")
            return None
    
    def evaluate_report_state(self, state: Dict[str, Any]) -> Dict[str, List[ReliabilityScore]]:
        """LangGraph의 ReportState를 받아 전체 리포트의 신뢰도 평가
        
        Args:
            state: LangGraph ReportState 딕셔너리
                필수 필드:
                - active_sections: List[str]
                - section_queries: Dict[section, Dict[card_type, str]]
                - narrative_evidence: Dict[section, Dict[card_type, List[EvidenceItem]]]
                - section_cards: Dict[section, List[Dict[str, Any]]]
        
        Returns:
            섹션별 신뢰도 점수 딕셔너리
            {
                "sleep": [ReliabilityScore(card_type="problem", ...), ...],
                "uv": [ReliabilityScore(card_type="cause", ...), ...],
                ...
            }
        """
        print("\n" + "="*60)
        print("🔍 RAGAS 신뢰도 평가 시작")
        print("="*60)
        
        active_sections = state.get("active_sections", [])
        section_queries = state.get("section_queries", {})
        narrative_evidence = state.get("narrative_evidence", {})
        section_cards = state.get("section_cards", {})
        
        all_scores: Dict[str, List[ReliabilityScore]] = {}
        
        for section in active_sections:
            print(f"\n📊 [{section}] 섹션 평가 중...")
            section_scores = []
            
            queries = section_queries.get(section, {})
            evidence = narrative_evidence.get(section, {})
            cards = section_cards.get(section, [])
            
            # 카드 타입별로 평가
            for card_type in ["problem", "cause", "action"]:
                # 1. Question: 쿼리
                question = queries.get(card_type, "")
                
                # 2. Contexts: EvidenceItem 리스트에서 텍스트 추출
                evidence_items = evidence.get(card_type, [])
                contexts = []
                for item in evidence_items:
                    if isinstance(item, EvidenceItem):
                        contexts.append(item.text)
                    elif isinstance(item, dict) and "text" in item:
                        contexts.append(item["text"])
                
                # 3. Answer: 해당 카드 타입의 카드 텍스트
                answer = ""
                for card in cards:
                    if isinstance(card, dict) and card.get("card_type") == card_type:
                        answer = card.get("text", "")
                        break
                
                # 평가 실행
                score = self.evaluate_section(
                    section=section,
                    card_type=card_type,
                    question=question,
                    contexts=contexts,
                    answer=answer
                )
                
                if score:
                    section_scores.append(score)
            
            if section_scores:
                all_scores[section] = section_scores
        
        print("\n" + "="*60)
        print("✅ RAGAS 신뢰도 평가 완료")
        print("="*60 + "\n")
        
        return all_scores
    
    def print_summary(self, scores: Dict[str, List[ReliabilityScore]]):
        """평가 결과 요약 출력"""
        print("\n" + "="*60)
        print("📈 신뢰도 평가 결과 요약")
        print("="*60)
        
        total_cards = 0
        grade_counts = {"Verified": 0, "Plausible": 0, "Caution": 0}
        total_faithfulness = 0.0
        total_relevancy = 0.0
        
        for section, section_scores in scores.items():
            print(f"\n[{section}]")
            for score in section_scores:
                total_cards += 1
                grade_counts[score.grade] += 1
                total_faithfulness += score.faithfulness_score
                total_relevancy += score.relevancy_score
                
                print(f"  {score.card_type:8s}: "
                      f"{score.grade:10s} ({score.color:6s}) | "
                      f"Faith={score.faithfulness_score:.3f}, "
                      f"Relev={score.relevancy_score:.3f}, "
                      f"Avg={score.average_score:.3f}")
        
        if total_cards > 0:
            avg_faithfulness = total_faithfulness / total_cards
            avg_relevancy = total_relevancy / total_cards
            avg_overall = (avg_faithfulness + avg_relevancy) / 2
            
            print("\n" + "-"*60)
            print(f"전체 평균:")
            print(f"  Faithfulness: {avg_faithfulness:.3f}")
            print(f"  Relevancy:    {avg_relevancy:.3f}")
            print(f"  Overall:      {avg_overall:.3f}")
            print(f"\n등급 분포:")
            print(f"  ✅ Verified (Green):  {grade_counts['Verified']}개")
            print(f"  🔵 Plausible (Blue):  {grade_counts['Plausible']}개")
            print(f"  ⚠️ Caution (Yellow):  {grade_counts['Caution']}개")
            print("="*60 + "\n")


def run_ragas_test(state: Dict[str, Any]) -> Dict[str, List[ReliabilityScore]]:
    """편의 함수: ReportState를 받아 신뢰도 평가 실행
    
    Args:
        state: LangGraph ReportState
    
    Returns:
        섹션별 신뢰도 점수 딕셔너리
    """
    auditor = ReliabilityAuditor()
    scores = auditor.evaluate_report_state(state)
    auditor.print_summary(scores)
    return scores


# ==================== 테스트 코드 ====================
if __name__ == "__main__":
    """로컬 테스트용 샘플 데이터"""
    
    # 샘플 State 생성 (실제 LangGraph 결과물 형태)
    sample_state = {
        "active_sections": ["sleep"],
        "section_queries": {
            "sleep": {
                "problem": "수면 부족 단기간 피부 장벽 수분",
                "cause": "수면 파편화 코르티솔 염증 피부",
                "action": "수면 연장 개입 시험 피부"
            }
        },
        "narrative_evidence": {
            "sleep": {
                "problem": [
                    EvidenceItem(
                        paper_id="test_paper_1",
                        chunk_id="test_chunk_1",
                        text="Sleep deprivation has been shown to impair skin barrier function and reduce hydration levels. Studies demonstrate that even one night of poor sleep can significantly affect skin integrity.",
                        score=0.95,
                        section_norm="sleep",
                        topics=["sleep"]
                    ),
                    EvidenceItem(
                        paper_id="test_paper_2",
                        chunk_id="test_chunk_2",
                        text="The skin's ability to retain moisture decreases with inadequate sleep, leading to increased transepidermal water loss.",
                        score=0.89,
                        section_norm="sleep",
                        topics=["sleep"]
                    )
                ],
                "cause": [
                    EvidenceItem(
                        paper_id="test_paper_3",
                        chunk_id="test_chunk_3",
                        text="Sleep fragmentation increases cortisol levels, which triggers inflammatory responses in skin tissue.",
                        score=0.92,
                        section_norm="sleep",
                        topics=["sleep"]
                    )
                ],
                "action": [
                    EvidenceItem(
                        paper_id="test_paper_4",
                        chunk_id="test_chunk_4",
                        text="Sleep extension interventions have shown improvements in skin hydration and barrier function within 2-4 weeks.",
                        score=0.88,
                        section_norm="sleep",
                        topics=["sleep"]
                    )
                ]
            }
        },
        "section_cards": {
            "sleep": [
                {
                    "card_type": "problem",
                    "text": "수면이 부족하면 피부의 장벽 기능이 저하되어 수분 손실이 증가합니다. 단 하루의 수면 부족도 피부 건강에 영향을 줄 수 있습니다."
                },
                {
                    "card_type": "cause",
                    "text": "수면 파편화는 코르티솔 수치를 증가시켜 피부 조직에 염증 반응을 유발합니다."
                },
                {
                    "card_type": "action",
                    "text": "충분한 수면을 확보하면 2-4주 내에 피부 수분과 장벽 기능이 개선될 수 있습니다."
                }
            ]
        }
    }
    
    print("\n🧪 RAGAS 로컬 테스트 시작")
    print("="*60)
    print("샘플 데이터로 신뢰도 평가를 실행합니다...\n")
    
    try:
        # 평가 실행
        scores = run_ragas_test(sample_state)
        
        # 결과 확인
        if scores:
            print("\n✅ 테스트 성공! RAGAS 평가가 정상 작동합니다.")
        else:
            print("\n⚠️ 평가 결과가 없습니다. State 데이터를 확인하세요.")
            
    except Exception as e:
        print(f"\n❌ 테스트 실패: {e}")
        import traceback
        traceback.print_exc()
