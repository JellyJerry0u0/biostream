"""
코치 에이전트용 Pydantic 스키마.

SQLAlchemy 모델(UserProfile 등)과 이름이 겹치지 않도록 에이전트 관점의 스냅샷만 정의한다.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from enum import Enum
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


# ── 기본 enum ──


class GoalDomain(str, Enum):
    sleep = "sleep"
    exercise = "exercise"
    uv_protection = "uv_protection"
    alcohol = "alcohol"
    smoking = "smoking"
    stress = "stress"
    skin_routine = "skin_routine"
    general = "general"


class GoalStatus(str, Enum):
    active = "active"
    paused = "paused"
    completed = "completed"
    proposed_change_pending = "proposed_change_pending"


class DifficultyLevel(str, Enum):
    very_easy = "very_easy"
    easy = "easy"
    moderate = "moderate"
    hard = "hard"


class InterventionType(str, Enum):
    goal_downshift = "goal_downshift"
    goal_maintain = "goal_maintain"
    goal_upshift = "goal_upshift"
    environment_design = "environment_design"
    trigger_or_reminder = "trigger_or_reminder"
    barrier_inquiry = "barrier_inquiry"
    encouragement = "encouragement"
    single_micro_action = "single_micro_action"
    clarifying_question = "clarifying_question"
    relapse_support = "relapse_support"
    weekly_reflection = "weekly_reflection"


class SuggestedInterventionType(str, Enum):
    goal_downshift = "goal_downshift"
    environment_change = "environment_change"
    reminder = "reminder"
    inquiry = "inquiry"
    encouragement = "encouragement"
    micro_action = "micro_action"


class SupervisorPrimaryRoute(str, Enum):
    """supervisor_route 조건 분기 키 — LangGraph 노드 이름과 맞춘다."""

    ask_followup_question_node = "ask_followup_question_node"
    revise_goal_node = "revise_goal_node"
    deliver_micro_action_node = "deliver_micro_action_node"
    reinforce_success_node = "reinforce_success_node"
    detect_relapse_node = "detect_relapse_node"
    weekly_reflection_node = "weekly_reflection_node"


# ── 1. UserProfile (에이전트용 스냅샷) ──


class UserProfile(BaseModel):
    user_id: int
    nickname: str = ""
    birthdate: Optional[date] = None
    gender: Optional[str] = None
    smoking_status: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    survey_sleep_weekday_h: Optional[float] = None
    survey_sleep_weekend_h: Optional[float] = None
    survey_stress_0_10: Optional[float] = None
    survey_aerobic_bucket: Optional[str] = None
    survey_drinking_days_per_week: Optional[str] = None
    survey_sunscreen_frequency: Optional[str] = None
    data_sources: List[str] = Field(
        default_factory=list,
        description="예: survey, health_data_table, daily_snapshot, committed_actions",
    )


# ── 2. HealthLog ──


class HealthLog(BaseModel):
    log_id: str
    user_id: int
    log_date: date
    source: str = Field(description="self_report | health_data | healthkit | health_connect | snapshot")
    domain: GoalDomain = GoalDomain.general
    metric_key: str = Field(description="sleep_minutes, steps, exercise_minutes, outdoor_yes, ...")
    value_numeric: Optional[float] = None
    value_text: Optional[str] = None
    unit: Optional[str] = None
    raw: Dict[str, Any] = Field(default_factory=dict)


# ── 3~4. AdaptiveGoal, GoalRevision ──


class TargetHistoryEntry(BaseModel):
    recorded_at: datetime
    target_description: str
    unit: Optional[str] = None


class AdaptiveGoal(BaseModel):
    goal_id: str
    domain: GoalDomain
    description: str
    current_target: str
    unit: Optional[str] = None
    status: GoalStatus = GoalStatus.active
    confidence: float = Field(ge=0.0, le=1.0, default=0.7)
    difficulty_level: DifficultyLevel = DifficultyLevel.moderate
    last_updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    revision_reason: str = ""
    success_rate_7d: float = Field(ge=0.0, le=1.0, default=0.0)
    success_rate_30d: float = Field(ge=0.0, le=1.0, default=0.0)
    failure_patterns: List[str] = Field(default_factory=list)
    target_history: List[TargetHistoryEntry] = Field(default_factory=list)
    pending_user_approval: bool = False
    proposed_target: Optional[str] = None


class GoalRevision(BaseModel):
    revision_id: str
    goal_id: str
    previous_target: str
    new_target: str
    reason: str
    decided_by: Literal["user", "agent", "system"] = "agent"
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    pending_user_approval: bool = True


# ── 5~7. DerivedMetrics, AdherenceSummary, BehaviorPattern ──


class DerivedMetrics(BaseModel):
    bmi: Optional[float] = None
    sleep_avg_hours_7d: Optional[float] = None
    sleep_avg_hours_30d: Optional[float] = None
    sleep_trend_slope_hours_per_day: Optional[float] = None
    steps_avg_7d: Optional[float] = None
    exercise_minutes_avg_7d: Optional[float] = None
    outdoor_yes_rate_7d: Optional[float] = Field(
        default=None, description="0~1, UV/야외 응답 중 yes 비율"
    )
    goal_level_rates: Dict[str, float] = Field(
        default_factory=dict, description="goal_id -> 최근 7일 달성률 0~1"
    )
    consecutive_failure_streak_max: int = 0
    consecutive_success_streak_max: int = 0
    risky_phrase_flags: List[str] = Field(
        default_factory=list,
        description="사용자 메시지에서 위험 키워드 탐지 시 태그 (코칭 시 안전 문구용)",
    )


class AdherenceSummary(BaseModel):
    window_days: int = 7
    overall_adherence_0_1: float = 0.0
    by_goal_id: Dict[str, float] = Field(default_factory=dict)
    notes: List[str] = Field(default_factory=list)


class BehaviorPattern(BaseModel):
    pattern_id: str
    domain: GoalDomain
    summary: str
    evidence: List[str] = Field(default_factory=list)
    confidence: float = Field(ge=0.0, le=1.0, default=0.5)
    suggested_intervention_type: SuggestedInterventionType = SuggestedInterventionType.micro_action


# ── 8. CoachingMemory ──


class CoachingMemory(BaseModel):
    prefers_brief_replies: Optional[bool] = None
    responds_well_to_tone: Optional[Literal["warm", "neutral", "coaching", "playful"]] = None
    prefers_smaller_goals: Optional[bool] = None
    responds_well_to_questions_vs_direct: Optional[Literal["questions", "direct", "mixed"]] = None
    last_intervention_type: Optional[str] = None
    last_user_message_length_bucket: Optional[Literal["short", "medium", "long"]] = None
    episodic_highlights: List[str] = Field(
        default_factory=list, description="최근 개입·결과 한 줄 요약 (최대 수개)"
    )


class EpisodicEvent(BaseModel):
    event_id: str
    occurred_at: datetime
    kind: Literal["success", "failure", "intervention", "user_message", "followup_outcome"]
    summary: str
    related_goal_ids: List[str] = Field(default_factory=list)
    intervention_type: Optional[str] = None
    outcome_after_3d: Optional[str] = None
    outcome_after_7d: Optional[str] = None


# ── 9~11. SupervisorDecision, InterventionPlan, StructuredCoachingResponse ──


class SupervisorDecision(BaseModel):
    ask_followup_question: bool = False
    revise_goal: bool = False
    deliver_micro_action: bool = False
    reinforce_success: bool = False
    detect_relapse_pattern: bool = False
    generate_weekly_reflection: bool = False
    primary_route: SupervisorPrimaryRoute = SupervisorPrimaryRoute.deliver_micro_action_node
    rationale_codes: List[str] = Field(
        default_factory=list, description="deterministic 라우팅 근거 코드"
    )


class GoalUpdateProposal(BaseModel):
    goal_id: str
    proposed_target: str
    reason: str
    pending_user_approval: bool = True


class InterventionPlan(BaseModel):
    behavior_hypothesis: str = ""
    intervention_type: InterventionType = InterventionType.single_micro_action
    target_goal_ids: List[str] = Field(default_factory=list)
    recommended_goal_updates: List[GoalUpdateProposal] = Field(default_factory=list)
    today_actions: List[str] = Field(
        default_factory=list, description="실행 가능한 행동 1~3개 (짧은 문장)"
    )
    followup_question: Optional[str] = None
    tone_strategy: Literal["warm", "neutral", "coaching"] = "warm"
    success_measure: str = ""
    reasoning_summary: str = ""


class StructuredCoachingResponse(BaseModel):
    headline: str = Field(description="첫 문장 결론")
    empathy_line: str = ""
    rationale_short: str = Field(description="왜 이 제안인지 1~2문장, 비진단적 표현")
    micro_actions: List[str] = Field(default_factory=list, description="최대 3개")
    optional_question: Optional[str] = None
    safety_disclaimer_line: Optional[str] = Field(
        default=None,
        description="필요 시 전문가 상담 권고 등",
    )

