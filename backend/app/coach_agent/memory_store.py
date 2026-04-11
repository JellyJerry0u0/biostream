"""
에이전트 지속 상태 저장.

WS 세션의 `coach_agent_persisted` 가 1차 저장소이며, 턴 종료·목표 동의 시
`db_persistence.persist_user_coach_state` 로 `user_coach_agent_states` 테이블에 동기화한다.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Any, Dict, List

from pydantic import TypeAdapter

from app.coach_agent.schemas import AdaptiveGoal, CoachingMemory, EpisodicEvent, GoalRevision


class CoachAgentMemoryStore(ABC):
    @abstractmethod
    def load(self) -> Dict[str, Any]:
        ...

    @abstractmethod
    def save(self, blob: Dict[str, Any]) -> None:
        ...


class SessionDictCoachMemoryStore(CoachAgentMemoryStore):
    """SessionData.coach_agent_persisted 에 읽기/쓰기."""

    def __init__(self, session: Any):
        self._session = session

    def load(self) -> Dict[str, Any]:
        raw = getattr(self._session, "coach_agent_persisted", None) or {}
        if not isinstance(raw, dict):
            return {}
        return dict(raw)

    def save(self, blob: Dict[str, Any]) -> None:
        self._session.coach_agent_persisted = blob


def parse_persisted(blob: Dict[str, Any]) -> tuple[
    List[AdaptiveGoal],
    List[GoalRevision],
    List[EpisodicEvent],
    CoachingMemory,
]:
    goals = TypeAdapter(List[AdaptiveGoal]).validate_python(blob.get("active_goals") or [])
    hist = TypeAdapter(List[GoalRevision]).validate_python(blob.get("goal_history") or [])
    episodic = TypeAdapter(List[EpisodicEvent]).validate_python(blob.get("episodic_memory") or [])
    cm_raw = blob.get("coaching_memory") or {}
    coaching = CoachingMemory.model_validate(cm_raw) if cm_raw else CoachingMemory()
    return goals, hist, episodic, coaching


def serialize_persisted(
    goals: List[AdaptiveGoal],
    goal_history: List[GoalRevision],
    episodic: List[EpisodicEvent],
    coaching: CoachingMemory,
) -> Dict[str, Any]:
    return {
        "active_goals": [g.model_dump(mode="json") for g in goals],
        "goal_history": [h.model_dump(mode="json") for h in goal_history],
        "episodic_memory": [e.model_dump(mode="json") for e in episodic[-40:]],
        "coaching_memory": coaching.model_dump(mode="json"),
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
