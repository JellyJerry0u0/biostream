"""
RAGAS 기반 리포트 신뢰도 평가 도구 (MCP Server용)

LangGraph로 생성된 리포트의 신뢰도를 RAGAS로 평가하고 결과를 반환합니다.
"""

import os
import sys
from typing import Dict, Any, List, Optional
from pathlib import Path

# backend 디렉토리를 경로에 추가
backend_dir = Path(__file__).parent.parent.parent.absolute()
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from tools.reliability_auditor import ReliabilityAuditor, ReliabilityScore


def evaluate_report_reliability(
    report_state: Dict[str, Any],
    gemini_api_key: Optional[str] = None
) -> Dict[str, Any]:
    """
    LangGraph ReportState의 신뢰도를 RAGAS로 평가
    
    Args:
        report_state: LangGraph ReportState 딕셔너리
            필수 필드:
            - active_sections: List[str]
            - section_queries: Dict[section, Dict[card_type, str]]
            - narrative_evidence: Dict[section, Dict[card_type, List[EvidenceItem]]]
            - section_cards: Dict[section, List[Dict[str, Any]]]
        gemini_api_key: Gemini API Key (옵션, 없으면 환경변수 사용)
    
    Returns:
        {
            "success": bool,
            "scores": {
                "sleep": [
                    {
                        "section": "sleep",
                        "card_type": "problem",
                        "faithfulness_score": 0.95,
                        "relevancy_score": 0.88,
                        "average_score": 0.915,
                        "grade": "Verified",
                        "color": "Green",
                        "message": "모든 내용이 논문 근거와 일치합니다.",
                        "question": "...",
                        "contexts_count": 8,
                        "answer_length": 450
                    },
                    ...
                ],
                ...
            },
            "statistics": {
                "total_cards": 9,
                "avg_faithfulness": 0.887,
                "avg_relevancy": 0.856,
                "avg_overall": 0.872,
                "grade_counts": {
                    "Verified": 4,
                    "Plausible": 5,
                    "Caution": 0
                },
                "overall_grade": "Plausible",
                "overall_color": "Blue"
            }
        }
    """
    try:
        # ReliabilityAuditor 초기화
        auditor = ReliabilityAuditor(api_key=gemini_api_key)
        
        # RAGAS 평가 실행
        scores = auditor.evaluate_report_state(report_state)
        
        # 결과를 직렬화 가능한 형태로 변환
        serialized_scores = {}
        for section, section_scores in scores.items():
            serialized_scores[section] = [
                {
                    "section": score.section,
                    "card_type": score.card_type,
                    "faithfulness_score": score.faithfulness_score,
                    "relevancy_score": score.relevancy_score,
                    "average_score": score.average_score,
                    "grade": score.grade,
                    "color": score.color,
                    "message": score.message,
                    "question": score.question,
                    "contexts_count": score.contexts_count,
                    "answer_length": score.answer_length
                }
                for score in section_scores
            ]
        
        # 전체 통계 계산
        all_scores = [score for section_scores in scores.values() for score in section_scores]
        
        if all_scores:
            total_cards = len(all_scores)
            avg_faithfulness = sum(s.faithfulness_score for s in all_scores) / total_cards
            avg_relevancy = sum(s.relevancy_score for s in all_scores) / total_cards
            avg_overall = sum(s.average_score for s in all_scores) / total_cards
            
            grade_counts = {"Verified": 0, "Plausible": 0, "Caution": 0}
            for score in all_scores:
                grade_counts[score.grade] += 1
            
            # 전체 등급 결정
            if avg_overall >= 0.9:
                overall_grade = "Verified"
                overall_color = "Green"
            elif avg_overall >= 0.7:
                overall_grade = "Plausible"
                overall_color = "Blue"
            else:
                overall_grade = "Caution"
                overall_color = "Yellow"
            
            statistics = {
                "total_cards": total_cards,
                "avg_faithfulness": round(avg_faithfulness, 3),
                "avg_relevancy": round(avg_relevancy, 3),
                "avg_overall": round(avg_overall, 3),
                "grade_counts": grade_counts,
                "overall_grade": overall_grade,
                "overall_color": overall_color
            }
        else:
            statistics = {
                "total_cards": 0,
                "avg_faithfulness": 0.0,
                "avg_relevancy": 0.0,
                "avg_overall": 0.0,
                "grade_counts": {"Verified": 0, "Plausible": 0, "Caution": 0},
                "overall_grade": "Unknown",
                "overall_color": "Gray"
            }
        
        return {
            "success": True,
            "scores": serialized_scores,
            "statistics": statistics
        }
        
    except Exception as e:
        import traceback
        return {
            "success": False,
            "error": str(e),
            "traceback": traceback.format_exc()
        }


def get_section_reliability(
    section: str,
    card_type: str,
    question: str,
    contexts: List[str],
    answer: str,
    gemini_api_key: Optional[str] = None
) -> Dict[str, Any]:
    """
    단일 섹션-카드의 신뢰도 평가
    
    Args:
        section: 섹션 이름 (예: "sleep", "uv")
        card_type: 카드 타입 (예: "problem", "cause", "action")
        question: 질문 (쿼리)
        contexts: 근거 텍스트 리스트
        answer: 생성된 답변
        gemini_api_key: Gemini API Key (옵션)
    
    Returns:
        {
            "success": bool,
            "score": {
                "section": "sleep",
                "card_type": "problem",
                "faithfulness_score": 0.95,
                "relevancy_score": 0.88,
                "average_score": 0.915,
                "grade": "Verified",
                "color": "Green",
                "message": "...",
                ...
            }
        }
    """
    try:
        auditor = ReliabilityAuditor(api_key=gemini_api_key)
        
        score = auditor.evaluate_section(
            section=section,
            card_type=card_type,
            question=question,
            contexts=contexts,
            answer=answer
        )
        
        if score:
            return {
                "success": True,
                "score": {
                    "section": score.section,
                    "card_type": score.card_type,
                    "faithfulness_score": score.faithfulness_score,
                    "relevancy_score": score.relevancy_score,
                    "average_score": score.average_score,
                    "grade": score.grade,
                    "color": score.color,
                    "message": score.message,
                    "question": score.question,
                    "contexts_count": score.contexts_count,
                    "answer_length": score.answer_length
                }
            }
        else:
            return {
                "success": False,
                "error": "평가 실패 - 결과 없음"
            }
            
    except Exception as e:
        import traceback
        return {
            "success": False,
            "error": str(e),
            "traceback": traceback.format_exc()
        }
