"""코치 에이전트 deterministic 로직·그래프 스모크."""

from app.coach_agent.deterministic import (
    compute_derived_metrics,
    deterministic_behavior_patterns,
    supervisor_decide,
)
from app.coach_agent.graph import build_coach_agent_graph
from app.coach_agent.mock_data import sample_goals, sample_logs, sample_profile
from app.coach_agent.schemas import (
    AdaptiveGoal,
    GoalDomain,
    GoalStatus,
    SupervisorPrimaryRoute,
    UserProfile,
)


def test_compute_derived_metrics_sleep_trend():
    prof = sample_profile()
    logs = sample_logs()
    goals = sample_goals()
    dm, adher = compute_derived_metrics(prof, logs, goals, user_message="")
    assert dm.sleep_avg_hours_7d is not None
    assert adher.window_days == 7


def test_supervisor_routes_revise_on_low_rate():
    prof = UserProfile(user_id=1, nickname="a", height_cm=170, weight_kg=70)
    from app.coach_agent.schemas import AdherenceSummary, BehaviorPattern, DerivedMetrics, SuggestedInterventionType

    dm = DerivedMetrics(consecutive_failure_streak_max=2)
    adher = AdherenceSummary(overall_adherence_0_1=0.2)
    patterns = [
        BehaviorPattern(
            pattern_id="1",
            domain=GoalDomain.sleep,
            summary="낮은 달성",
            suggested_intervention_type=SuggestedInterventionType.goal_downshift,
        )
    ]
    goals = [
        AdaptiveGoal(
            goal_id="g1",
            domain=GoalDomain.sleep,
            description="x",
            current_target="7h",
            success_rate_7d=0.2,
            status=GoalStatus.active,
        )
    ]
    dec = supervisor_decide(
        prof, dm, adher, patterns, [], "피곤해요", active_goals=goals
    )
    assert dec.primary_route == SupervisorPrimaryRoute.revise_goal_node


def test_graph_compiles():
    build_coach_agent_graph()
