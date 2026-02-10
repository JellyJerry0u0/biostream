"""
세션 스토어: in-memory 세션 · 히스토리 · 캐시 관리
- 세션 ID 기준으로 대화 히스토리, 코치 메모리, 리포트 캐시를 유지한다.
- 최근 N턴(기본 10) 히스토리만 유지하여 메모리를 절약한다.
"""

import time
import uuid
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field


# ── 데이터 클래스 ──

@dataclass
class ChatTurn:
    """대화 한 턴"""
    role: str           # "user" | "assistant"
    content: str
    timestamp: float = field(default_factory=time.time)


@dataclass
class SessionData:
    """세션 전체 데이터"""
    session_id: str
    user_id: Optional[int] = None
    report_id: Optional[int] = None

    # 대화 히스토리
    history: List[ChatTurn] = field(default_factory=list)

    # 코치 메모리 (dict → CoachMemory 로 관리)
    coach_memory_dict: Dict[str, Any] = field(default_factory=dict)

    # 캐시
    report_summary_cache: Optional[Dict[str, Any]] = None
    rag_cache: List[Dict[str, Any]] = field(default_factory=list)

    # 엔진 모드: "quick" (함수 체이닝) | "deep" (LangGraph + tool calling)
    engine: str = "quick"

    # 마지막 RAG 검색 결과 텍스트 (근거 보기에서 사용)
    last_rag_text: Optional[str] = None

    created_at: float = field(default_factory=time.time)
    last_active: float = field(default_factory=time.time)

    MAX_HISTORY_TURNS: int = 10        # 최근 N 턴(user+assistant 각 1)
    MAX_RAG_CACHE: int = 3

    # ── 히스토리 ──

    def add_turn(self, role: str, content: str):
        """대화 턴 추가 (최근 MAX_HISTORY_TURNS 쌍만 유지)"""
        self.history.append(ChatTurn(role=role, content=content))
        max_items = self.MAX_HISTORY_TURNS * 2
        if len(self.history) > max_items:
            self.history = self.history[-max_items:]
        self.last_active = time.time()

    def get_history_for_prompt(self) -> List[Dict[str, str]]:
        """프롬프트에 넣을 최근 히스토리"""
        recent = self.history[-(self.MAX_HISTORY_TURNS * 2):]
        return [{"role": t.role, "content": t.content} for t in recent]

    # ── RAG 캐시 ──

    def cache_rag_result(self, result: Dict[str, Any]):
        """RAG 결과 캐시 (최근 N개)"""
        self.rag_cache.append(result)
        if len(self.rag_cache) > self.MAX_RAG_CACHE:
            self.rag_cache = self.rag_cache[-self.MAX_RAG_CACHE:]


# ── 세션 저장소 (싱글톤) ──

class SessionStore:
    """글로벌 in-memory 세션 저장소"""

    def __init__(self, ttl_seconds: int = 3600):
        self._sessions: Dict[str, SessionData] = {}
        self._ttl = ttl_seconds

    def get_or_create(
        self,
        session_id: Optional[str] = None,
        user_id: Optional[int] = None,
        report_id: Optional[int] = None,
    ) -> SessionData:
        """세션 조회 또는 생성"""
        self._cleanup_expired()

        if session_id and session_id in self._sessions:
            session = self._sessions[session_id]
            session.last_active = time.time()
            if user_id:
                session.user_id = user_id
            if report_id:
                session.report_id = report_id
            return session

        new_id = session_id or str(uuid.uuid4())
        session = SessionData(
            session_id=new_id,
            user_id=user_id,
            report_id=report_id,
        )
        self._sessions[new_id] = session
        return session

    def get(self, session_id: str) -> Optional[SessionData]:
        """세션 조회"""
        session = self._sessions.get(session_id)
        if session:
            session.last_active = time.time()
        return session

    def _cleanup_expired(self):
        """만료된 세션 정리"""
        now = time.time()
        expired = [
            sid for sid, s in self._sessions.items()
            if now - s.last_active > self._ttl
        ]
        for sid in expired:
            del self._sessions[sid]


# 싱글톤 인스턴스
session_store = SessionStore()
