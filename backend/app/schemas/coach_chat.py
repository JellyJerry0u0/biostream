"""
코치 챗봇 WebSocket 메시지 스키마
클라이언트 ↔ 서버 간 JSON 메시지 타입 정의
"""

from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from enum import Enum


# ══════════════════════════════════════════════
#  Enums
# ══════════════════════════════════════════════

class ChatMode(str, Enum):
    """의도 힌트 — LLM 프롬프트 톤을 결정"""
    COACH = "coach"
    REPORT_EXPLAIN = "report_explain"
    AUTO = "auto"


class CoachEngine(str, Enum):
    """실행 엔진 — Quick(함수 체이닝) vs Deep(LangGraph + tool calling)"""
    QUICK = "quick"
    DEEP = "deep"


# ══════════════════════════════════════════════
#  클라이언트 → 서버
# ══════════════════════════════════════════════

class UserMessagePayload(BaseModel):
    """사용자 메시지"""
    type: str = "user_message"
    session_id: Optional[str] = None
    message: str
    report_id: Optional[int] = None          # lifestyle_id 와 동일하게 사용
    user_context: Optional[Dict[str, Any]] = None
    mode: ChatMode = ChatMode.AUTO
    engine: Optional[CoachEngine] = None     # 메시지 단위 오버라이드 (없으면 세션 설정)


class ActionEventPayload(BaseModel):
    """액션 버튼 클릭 이벤트"""
    type: str = "action"
    session_id: Optional[str] = None
    action_id: str
    payload: Optional[Dict[str, Any]] = None


class ModeSwitchPayload(BaseModel):
    """엔진 모드 전환 요청"""
    type: str = "mode_switch"
    engine: CoachEngine


# ══════════════════════════════════════════════
#  서버 → 클라이언트
# ══════════════════════════════════════════════

class StreamStart(BaseModel):
    type: str = "start"
    session_id: str
    assistant_message_id: str


class StreamDelta(BaseModel):
    type: str = "delta"
    assistant_message_id: str
    delta: str


class ActionItem(BaseModel):
    id: str
    label: str
    payload: Optional[Dict[str, Any]] = None


class StreamActions(BaseModel):
    type: str = "actions"
    assistant_message_id: str
    items: List[ActionItem]


class CitationItem(BaseModel):
    paper_id: Optional[str] = None
    chunk_id: Optional[str] = None
    source_section: Optional[str] = None
    score: Optional[float] = None
    source_chunk_id: Optional[str] = None


class StreamCitations(BaseModel):
    type: str = "citations"
    assistant_message_id: str
    items: List[CitationItem]


class MemoryItem(BaseModel):
    key: str
    value: str


class StreamMemoryUpdate(BaseModel):
    type: str = "memory_update"
    items: List[MemoryItem]


class StreamModeInfo(BaseModel):
    """엔진 모드 전환 확인"""
    type: str = "mode_info"
    engine: str
    label: str


class StreamToolStatus(BaseModel):
    """Deep 모드에서 도구 실행 상태"""
    type: str = "tool_status"
    assistant_message_id: Optional[str] = None
    tool: str
    status: str      # "running" | "done" | "error"


class StreamDone(BaseModel):
    type: str = "done"
    assistant_message_id: str


class StreamError(BaseModel):
    type: str = "error"
    message: str
    assistant_message_id: Optional[str] = None
