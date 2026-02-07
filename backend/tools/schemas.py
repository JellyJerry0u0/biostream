"""
Pydantic 스키마 정의
Qdrant 검색, 리포트 생성 등에 사용되는 데이터 모델을 정의합니다.
"""

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class EvidenceItem(BaseModel):
    """검색된 근거 항목"""
    paper_id: str
    chunk_id: str
    text: str
    score: float
    section_norm: str
    topics: List[str]
    pmid: Optional[str] = None
    title: Optional[str] = None


class QdrantSearchInput(BaseModel):
    """Qdrant 검색 입력 파라미터"""
    query: str = Field(..., description="검색 쿼리 텍스트")
    top_k: int = Field(default=5, description="반환할 최대 결과 수")
    topics: Optional[List[str]] = Field(default=None, description="필터링할 토픽 리스트")
    section_norm: Optional[str] = Field(default=None, description="섹션 필터")
    candidate_k: int = Field(default=20, description="1차 검색 후보 수")
    min_score: float = Field(default=0.5, description="최소 유사도 점수")


class QdrantSearchOutput(BaseModel):
    """Qdrant 검색 결과"""
    items: List[EvidenceItem]
    total_found: int
    search_method: str = Field(..., description="사용된 검색 방법 (1차/2차)")


class ReportRequest(BaseModel):
    """리포트 생성 요청"""
    user_id: int


class ReportResponse(BaseModel):
    """리포트 생성 응답"""
    success: bool
    report: Optional[Dict[str, Any]] = None
    report_id: Optional[str] = None
    timestamp: Optional[str] = None
    error: Optional[str] = None
