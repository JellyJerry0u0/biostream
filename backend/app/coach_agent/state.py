"""
LangGraph StateGraph 상태.

LangGraph StateGraph용 TypedDict로 두고,
중첩 구조는 Pydantic model_dump() dict로 보관한다.
"""

from __future__ import annotations

from typing import Any, Dict, List, TypedDict


class CoachAgentState(TypedDict, total=False):
    user_id: int
    current_message: str
    conversation_history: List[Dict[str, str]]
    profile: Dict[str, Any]
    recent_health_logs: List[Dict[str, Any]]
    active_goals: List[Dict[str, Any]]
    goal_history: List[Dict[str, Any]]
    derived_metrics: Dict[str, Any]
    adherence_summary: Dict[str, Any]
    behavior_patterns: List[Dict[str, Any]]
    coaching_memory: Dict[str, Any]
    episodic_memory: List[Dict[str, Any]]
    missing_info: List[str]
    supervisor_decision: Dict[str, Any]
    intervention_plan: Dict[str, Any]
    structured_response: Dict[str, Any]
    final_response: str
    report_ctx: Dict[str, Any]
    mode: str
    # 오늘 첫 스냅샷 저장 등: 슈퍼바이저를 릴랩스/목표완화 쪽으로 고정
    snapshot_nudge_mode: bool
    # 런타임 (직렬화 제외)
    session: Any
    db: Any
    send_json: Any
    assistant_msg_id: str
    # load_user_context에서만 채우는 파싱 캐시 (직렬화 생략)
    _parsed_goals: Any
    _parsed_logs: Any
    _checkin_by_goal: Any
