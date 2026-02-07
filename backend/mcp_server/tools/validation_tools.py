"""
리포트 섹션 검증 도구

LLM이 생성한 리포트 섹션이 구조화된 형식인지 검증합니다.
"""

import json
import re
from typing import Dict, Any, List, Optional


def validate_section_structure(section_content: str, section_type: str) -> Dict[str, Any]:
    """
    리포트 섹션의 구조화 여부를 검증합니다.
    
    Args:
        section_content: 검증할 섹션 내용
        section_type: 섹션 타입 (goals, sleep, uv, lifestyle, activity)
    
    Returns:
        검증 결과 딕셔너리
    """
    try:
        # 기본 검증 항목
        has_numbered_list = bool(re.search(r'\d+\.', section_content))
        has_structure = bool(re.search(r'[:\-]', section_content))
        min_length = len(section_content) > 100  # 최소 100자 이상
        
        # 섹션 타입별 필수 키워드 체크
        required_keywords = {
            "goals": ["분석", "결과", "개선", "권장", "목표"],
            "sleep": ["수면", "평가", "영향", "권장"],
            "uv": ["자외선", "노출", "영향", "권장", "선크림"],
            "lifestyle": ["생활습관", "평가", "영향", "권장"],
            "activity": ["운동", "활동", "평가", "영향", "권장"]
        }
        
        keywords = required_keywords.get(section_type, [])
        has_required_keywords = any(keyword in section_content for keyword in keywords)
        
        # 구조화 점수 계산 (0-100)
        structure_score = 0
        if has_numbered_list:
            structure_score += 30
        if has_structure:
            structure_score += 20
        if min_length:
            structure_score += 20
        if has_required_keywords:
            structure_score += 30
        
        # 구조화 여부 판단 (70점 이상이면 구조화됨)
        is_structured = structure_score >= 70
        
        # 섹션을 파싱하여 구조 추출
        parsed_structure = parse_section_structure(section_content)
        
        return {
            "is_valid": is_structured,
            "structure_score": structure_score,
            "has_numbered_list": has_numbered_list,
            "has_structure_markers": has_structure,
            "meets_minimum_length": min_length,
            "has_required_keywords": has_required_keywords,
            "parsed_structure": parsed_structure,
            "recommendations": get_improvement_recommendations(is_structured, structure_score)
        }
        
    except Exception as e:
        return {
            "is_valid": False,
            "error": str(e),
            "structure_score": 0
        }


def parse_section_structure(content: str) -> Dict[str, Any]:
    """섹션 내용을 파싱하여 구조를 추출합니다."""
    structure = {
        "sections": [],
        "bullet_points": [],
        "numbered_items": []
    }
    
    # 번호 목록 추출
    numbered_pattern = r'\d+\.\s+([^\n]+)'
    numbered_items = re.findall(numbered_pattern, content)
    structure["numbered_items"] = numbered_items
    
    # 주요 섹션 제목 추출 (예: "1. 현재 상태 분석:")
    section_pattern = r'(\d+\.\s+[^\n:]+:)'
    sections = re.findall(section_pattern, content)
    structure["sections"] = sections
    
    return structure


def get_improvement_recommendations(is_structured: bool, score: int) -> List[str]:
    """구조화 개선 권장사항을 제공합니다."""
    recommendations = []
    
    if not is_structured:
        if score < 30:
            recommendations.append("번호 목록 형식(1., 2., 3.)을 사용하여 구조화하세요.")
        if score < 50:
            recommendations.append("섹션별 제목을 명확히 구분하세요.")
        if score < 70:
            recommendations.append("각 항목에 대한 상세한 설명을 추가하세요.")
    
    return recommendations
