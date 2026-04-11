"""
집계·통계·라우팅은 전부 deterministic.

LLM은 해석/문장 생성에만 쓰고, 수치 판단은 여기서 끝낸다.
"""

from __future__ import annotations

import re
import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta
from statistics import mean
from typing import Any, Dict, List, Optional, Tuple

from app.coach_agent.schemas import (
    AdaptiveGoal,
    AdherenceSummary,
    BehaviorPattern,
    DerivedMetrics,
    GoalDomain,
    GoalStatus,
    GoalUpdateProposal,
    HealthLog,
    InterventionPlan,
    InterventionType,
    SupervisorDecision,
    SupervisorPrimaryRoute,
    SuggestedInterventionType,
    UserProfile,
)


_RISK_PATTERNS = [
    (r"자해|죽고\s*싶|극도의\s*우울", "crisis_language"),
    (r"가슴\s*통증|호흡\s*곤란|실신", "acute_physical"),
]


def detect_risk_flags(user_message: str) -> List[str]:
    flags: List[str] = []
    for pat, tag in _RISK_PATTERNS:
        if re.search(pat, user_message):
            flags.append(tag)
    return flags


def compute_missing_profile_fields(profile: UserProfile) -> List[str]:
    missing: List[str] = []
    if profile.height_cm is None or profile.height_cm <= 0:
        missing.append("height_cm")
    if profile.weight_kg is None or profile.weight_kg <= 0:
        missing.append("weight_kg")
    return missing


def _logs_last_days(logs: List[HealthLog], days: int, end: date) -> List[HealthLog]:
    start = end - timedelta(days=days - 1)
    return [x for x in logs if start <= x.log_date <= end]


def compute_derived_metrics(
    profile: UserProfile,
    logs: List[HealthLog],
    active_goals: List[AdaptiveGoal],
    checkin_by_goal: Optional[Dict[str, List[Tuple[date, bool]]]] = None,
    today: Optional[date] = None,
    user_message: str = "",
) -> Tuple[DerivedMetrics, AdherenceSummary]:
    end = today or date.today()
    logs_7 = _logs_last_days(logs, 7, end)
    logs_30 = _logs_last_days(logs, 30, end)

    bmi: Optional[float] = None
    if profile.height_cm and profile.weight_kg and profile.height_cm > 0:
        h_m = profile.height_cm / 100.0
        bmi = round(profile.weight_kg / (h_m * h_m), 2)

    def sleep_avgs(bucket: List[HealthLog]) -> Optional[float]:
        vals = [
            x.value_numeric / 60.0
            for x in bucket
            if x.metric_key == "sleep_minutes" and x.value_numeric and x.value_numeric > 0
        ]
        if not vals:
            return None
        return round(mean(vals), 2)

    sleep_7 = sleep_avgs(logs_7)
    sleep_30 = sleep_avgs(logs_30)

    sleep_trend: Optional[float] = None
    by_date: Dict[date, List[float]] = defaultdict(list)
    for x in logs_7:
        if x.metric_key == "sleep_minutes" and x.value_numeric and x.value_numeric > 0:
            by_date[x.log_date].append(x.value_numeric / 60.0)
    if len(by_date) >= 3:
        ordered = sorted(by_date.items())
        first = mean(ordered[0][1])
        last = mean(ordered[-1][1])
        sleep_trend = round((last - first) / max(len(ordered) - 1, 1), 3)

    steps_vals = [
        x.value_numeric for x in logs_7 if x.metric_key == "steps" and x.value_numeric
    ]
    steps_avg = round(mean(steps_vals), 1) if steps_vals else None

    ex_vals = [
        x.value_numeric
        for x in logs_7
        if x.metric_key == "exercise_minutes" and x.value_numeric
    ]
    ex_avg = round(mean(ex_vals), 1) if ex_vals else None

    outdoor_ratios = [
        x.value_numeric
        for x in logs_7
        if x.metric_key == "outdoor_yes_ratio" and x.value_numeric is not None
    ]
    outdoor_rate = round(mean(outdoor_ratios), 3) if outdoor_ratios else None

    goal_rates: Dict[str, float] = {}
    streak_fail = 0
    streak_ok = 0
    if checkin_by_goal:
        for gid, checks in checkin_by_goal.items():
            recent = [c for _, c in sorted(checks, key=lambda z: z[0], reverse=True)[:7]]
            if recent:
                goal_rates[gid] = sum(1 for c in recent if c) / len(recent)
            # 연속 실패
            cf = 0
            for _, done in sorted(checks, key=lambda z: z[0], reverse=True):
                if not done:
                    cf += 1
                else:
                    break
            streak_fail = max(streak_fail, cf)
            cs = 0
            for _, done in sorted(checks, key=lambda z: z[0], reverse=True):
                if done:
                    cs += 1
                else:
                    break
            streak_ok = max(streak_ok, cs)

    dm = DerivedMetrics(
        bmi=bmi,
        sleep_avg_hours_7d=sleep_7,
        sleep_avg_hours_30d=sleep_30,
        sleep_trend_slope_hours_per_day=sleep_trend,
        steps_avg_7d=steps_avg,
        exercise_minutes_avg_7d=ex_avg,
        outdoor_yes_rate_7d=outdoor_rate,
        goal_level_rates=goal_rates,
        consecutive_failure_streak_max=streak_fail,
        consecutive_success_streak_max=streak_ok,
        risky_phrase_flags=detect_risk_flags(user_message),
    )

    overall = mean(goal_rates.values()) if goal_rates else 0.0
    notes: List[str] = []
    if sleep_trend and sleep_trend > 0.15:
        notes.append("최근 수면 시작이 늦어지는 추세(로그 기준)")
    if streak_fail >= 3:
        notes.append("습관 체크인 연속 미실천 구간이 김")

    adher = AdherenceSummary(
        window_days=7,
        overall_adherence_0_1=round(overall, 3),
        by_goal_id={k: round(v, 3) for k, v in goal_rates.items()},
        notes=notes,
    )
    return dm, adher


def deterministic_behavior_patterns(
    metrics: DerivedMetrics,
    adher: AdherenceSummary,
    goals: List[AdaptiveGoal],
    user_message: str,
) -> List[BehaviorPattern]:
    patterns: List[BehaviorPattern] = []

    if metrics.consecutive_failure_streak_max >= 3:
        patterns.append(
            BehaviorPattern(
                pattern_id=str(uuid.uuid4()),
                domain=GoalDomain.general,
                summary="최근 습관 체크에서 연속 미실천 구간이 관찰됩니다.",
                evidence=[
                    f"연속 미실천 최대 {metrics.consecutive_failure_streak_max}일",
                ],
                confidence=0.85,
                suggested_intervention_type=SuggestedInterventionType.goal_downshift,
            )
        )

    if metrics.sleep_trend_slope_hours_per_day and metrics.sleep_trend_slope_hours_per_day > 0.1:
        patterns.append(
            BehaviorPattern(
                pattern_id=str(uuid.uuid4()),
                domain=GoalDomain.sleep,
                summary="최근 며칠간 수면 시간이 점점 늦어지는 경향이 있습니다.",
                evidence=["7일 로그 기준 수면 시간 기울기 양(+)"],
                confidence=0.75,
                suggested_intervention_type=SuggestedInterventionType.micro_action,
            )
        )

    for g in goals:
        if g.domain == GoalDomain.sleep and metrics.sleep_avg_hours_7d:
            # 설문 목표 대비 단순 비교(텍스트 파싱 없이 보수적으로)
            if metrics.sleep_avg_hours_7d < 6.0 and g.status == GoalStatus.active:
                patterns.append(
                    BehaviorPattern(
                        pattern_id=str(uuid.uuid4()),
                        domain=GoalDomain.sleep,
                        summary="기록된 평균 수면이 6시간 미만으로 낮은 편입니다.",
                        evidence=[f"7일 평균 약 {metrics.sleep_avg_hours_7d}시간"],
                        confidence=0.7,
                        suggested_intervention_type=SuggestedInterventionType.goal_downshift,
                    )
                )

    if adher.overall_adherence_0_1 >= 0.75 and metrics.consecutive_success_streak_max >= 3:
        patterns.append(
            BehaviorPattern(
                pattern_id=str(uuid.uuid4()),
                domain=GoalDomain.general,
                summary="최근 실천이 꾸준히 이어지고 있습니다.",
                evidence=["7일 달성률 양호", "연속 실천 구간 존재"],
                confidence=0.72,
                suggested_intervention_type=SuggestedInterventionType.encouragement,
            )
        )

    if "야근" in user_message or "바빠" in user_message:
        patterns.append(
            BehaviorPattern(
                pattern_id=str(uuid.uuid4()),
                domain=GoalDomain.general,
                summary="바쁨·야근 등 시간 제약을 언급했습니다.",
                evidence=["사용자 메시지 키워드"],
                confidence=0.65,
                suggested_intervention_type=SuggestedInterventionType.environment_change,
            )
        )

    return patterns[:6]


def supervisor_decide(
    profile: UserProfile,
    metrics: DerivedMetrics,
    adher: AdherenceSummary,
    patterns: List[BehaviorPattern],
    missing_info: List[str],
    user_message: str,
    active_goals: List[AdaptiveGoal],
    coaching_hint_weekly: bool = False,
) -> SupervisorDecision:
    """
    우선순위 큐 방식 라우팅. 플래그는 복수 True 가능하지만 primary_route는 하나.
    """
    codes: List[str] = []
    um = user_message.strip()
    risk = detect_risk_flags(user_message)
    if risk:
        metrics.risky_phrase_flags = list({*(metrics.risky_phrase_flags or []), *risk})
        codes.append("safety_risk")

    if coaching_hint_weekly or re.search(r"이번\s*주|한\s*주|주간", um):
        codes.append("weekly_hint")
        return SupervisorDecision(
            generate_weekly_reflection=True,
            primary_route=SupervisorPrimaryRoute.weekly_reflection_node,
            rationale_codes=codes,
        )

    if len(um) < 8 and not any(ch.isalnum() for ch in um):
        codes.append("empty_or_trivial")
    elif len(um) < 12:
        codes.append("very_short_message")

    if missing_info and len(um) < 20:
        return SupervisorDecision(
            ask_followup_question=True,
            primary_route=SupervisorPrimaryRoute.ask_followup_question_node,
            rationale_codes=codes + ["missing_profile"],
        )

    if "crisis_language" in risk or "acute_physical" in risk:
        return SupervisorDecision(
            ask_followup_question=True,
            primary_route=SupervisorPrimaryRoute.ask_followup_question_node,
            rationale_codes=codes,
        )

    if metrics.consecutive_failure_streak_max >= 4:
        codes.append("streak_fail")
        return SupervisorDecision(
            detect_relapse_pattern=True,
            primary_route=SupervisorPrimaryRoute.detect_relapse_node,
            rationale_codes=codes,
        )

    if adher.overall_adherence_0_1 >= 0.8 and metrics.consecutive_success_streak_max >= 2:
        codes.append("high_adherence")
        return SupervisorDecision(
            reinforce_success=True,
            primary_route=SupervisorPrimaryRoute.reinforce_success_node,
            rationale_codes=codes,
        )

    goal_rate_low = False
    for g in active_goals:
        r = adher.by_goal_id.get(g.goal_id)
        if r is not None and r < 0.4:
            goal_rate_low = True
            break

    if metrics.consecutive_failure_streak_max >= 2 or adher.overall_adherence_0_1 < 0.35 or goal_rate_low:
        codes.append("low_adherence_or_failures")
        low_pattern = any(
            p.suggested_intervention_type == SuggestedInterventionType.goal_downshift
            for p in patterns
        )
        if low_pattern or adher.overall_adherence_0_1 < 0.35 or goal_rate_low:
            return SupervisorDecision(
                revise_goal=True,
                primary_route=SupervisorPrimaryRoute.revise_goal_node,
                rationale_codes=codes,
            )

    return SupervisorDecision(
        deliver_micro_action=True,
        primary_route=SupervisorPrimaryRoute.deliver_micro_action_node,
        rationale_codes=codes + ["default_micro_action"],
    )


def build_intervention_skeleton(
    route: SupervisorPrimaryRoute,
    patterns: List[BehaviorPattern],
    goals: List[AdaptiveGoal],
    metrics: DerivedMetrics,
    user_message: str,
) -> InterventionPlan:
    """분기 노드에서 개입 뼈대만 채운다. 문장 다듬기는 LLM 단계."""
    hypo = "사용자의 최근 기록과 메시지를 바탕으로 작은 행동 변화를 시도합니다."
    if patterns:
        hypo = patterns[0].summary

    if route == SupervisorPrimaryRoute.ask_followup_question_node:
        return InterventionPlan(
            behavior_hypothesis=hypo,
            intervention_type=InterventionType.clarifying_question,
            followup_question="지금 가장 부담이 큰 한 가지는 무엇인가요? 시간·환경 중에서 짧게 알려주세요.",
            tone_strategy="warm",
            today_actions=[],
            success_measure="사용자가 구체적 장애요인을 한 문장이라도 공유",
            reasoning_summary="정보가 부족해 안전하고 현실적인 개입을 고르기 어렵다.",
        )

    if route == SupervisorPrimaryRoute.detect_relapse_node:
        return InterventionPlan(
            behavior_hypothesis="연속 미실천이 길어져 동기·환경 측면 지원이 필요합니다.",
            intervention_type=InterventionType.relapse_support,
            tone_strategy="warm",
            today_actions=[
                "오늘은 목표의 절반만 생각하기: 딱 한 번만 체크할 수 있는 행동을 정하기",
            ],
            followup_question="가장 최근에 막힌 순간은 언제였나요? (예: 퇴근 후, 늦은 저녁)",
            success_measure="한 가지 장애요인 언어화",
            reasoning_summary="죄책감 없이 재시작할 수 있는 매우 작은 행동부터 제안.",
        )

    if route == SupervisorPrimaryRoute.reinforce_success_node:
        return InterventionPlan(
            behavior_hypothesis="최근 실천이 안정적이라 같은 리듬을 유지하는 전략이 유효합니다.",
            intervention_type=InterventionType.encouragement,
            tone_strategy="coaching",
            today_actions=["지금 잘 되고 있는 한 가지를 그대로 유지하기"],
            success_measure="내일도 동일 시간대에 한 번만 반복",
            reasoning_summary="성공 경험을 인지시켜 자기효능감을 유지.",
        )

    if route == SupervisorPrimaryRoute.weekly_reflection_node:
        return InterventionPlan(
            behavior_hypothesis="주간 단위로 패턴을 돌아보면 다음 주 전략 조정에 도움이 됩니다.",
            intervention_type=InterventionType.weekly_reflection,
            tone_strategy="neutral",
            today_actions=["이번 주 잘된 점 한 가지, 아쉬운 점 한 가지만 짧게 적어보기"],
            followup_question="다음 주에 가장 바꾸고 싶은 생활 한 가지는 무엇인가요?",
            success_measure="주간 회고 문장 1~2개",
            reasoning_summary="장기 목표보다 주간 루프로 적응 속도를 높임.",
        )

    if route == SupervisorPrimaryRoute.revise_goal_node:
        proposals: List[GoalUpdateProposal] = []
        for g in goals:
            if g.status != GoalStatus.active:
                continue
            if g.success_rate_7d < 0.45 or metrics.consecutive_failure_streak_max >= 2:
                proposals.append(
                    GoalUpdateProposal(
                        goal_id=g.goal_id,
                        proposed_target=f"{g.current_target} (더 작은 단계로 나누기)",
                        reason="최근 7일 달성률이 낮아, 부담을 줄인 목표로 다시 시작하는 편이 도움이 될 수 있습니다.",
                        pending_user_approval=True,
                    )
                )
        if not proposals and goals:
            g0 = next((x for x in goals if x.status == GoalStatus.active), goals[0])
            proposals.append(
                GoalUpdateProposal(
                    goal_id=g0.goal_id,
                    proposed_target=f"{g0.current_target} (주 3회 → 주 2회 등 빈도 완화)",
                    reason="연속 미실천이 있어 목표 강도를 잠시 낮추는 방향을 제안합니다.",
                    pending_user_approval=True,
                )
            )
        return InterventionPlan(
            behavior_hypothesis=hypo,
            intervention_type=InterventionType.goal_downshift,
            target_goal_ids=[p.goal_id for p in proposals[:3]],
            recommended_goal_updates=proposals[:3],
            today_actions=[
                "제안된 목표 조정에 괜찮다면 ‘동의’를 알려주세요. 부담되면 원하는 강도를 한 줄로 말해주세요.",
            ],
            tone_strategy="warm",
            success_measure="사용자 동의 후 목표 상태를 proposed_change_pending으로 저장",
            reasoning_summary="같은 목표를 반복 실패하면 동기만 소모되므로 단계 축소.",
        )

    # deliver_micro_action_node (default)
    actions: List[str] = [
        "오늘은 큰 변화 대신, 지금 할 수 있는 행동 하나만 5분 안에 실행하기",
    ]
    if metrics.sleep_avg_hours_7d and metrics.sleep_avg_hours_7d < 6.5:
        actions = [
            "오늘은 평소보다 15~20분만 일찍 눕는 준비를 해보기 (알람 하나만 조정)",
        ]
    return InterventionPlan(
        behavior_hypothesis=hypo,
        intervention_type=InterventionType.single_micro_action,
        today_actions=actions[:2],
        tone_strategy="warm",
        success_measure="제안 행동 중 1개 이상 실행 여부(자가 보고)",
        reasoning_summary="한 번에 행동을 많이 제시하지 않고 실행 가능성을 높임.",
    )


def pick_snapshot_coach_route(
    metrics: DerivedMetrics,
    adher: AdherenceSummary,
    active_goals: List[AdaptiveGoal],
) -> SupervisorPrimaryRoute:
    """첫 일일 스냅샷 저장 후 코치 넛지 — 릴랩스 vs 목표 완화 위주."""
    if metrics.consecutive_failure_streak_max >= 3:
        return SupervisorPrimaryRoute.detect_relapse_node
    if adher.overall_adherence_0_1 < 0.42:
        return SupervisorPrimaryRoute.revise_goal_node
    for g in active_goals:
        if g.status != GoalStatus.active:
            continue
        r = adher.by_goal_id.get(g.goal_id)
        if r is not None and r < 0.38:
            return SupervisorPrimaryRoute.revise_goal_node
    if metrics.consecutive_failure_streak_max >= 2:
        return SupervisorPrimaryRoute.detect_relapse_node
    return SupervisorPrimaryRoute.revise_goal_node


def supervisor_decision_for_snapshot_route(
    route: SupervisorPrimaryRoute,
) -> SupervisorDecision:
    if route == SupervisorPrimaryRoute.detect_relapse_node:
        return SupervisorDecision(
            detect_relapse_pattern=True,
            primary_route=route,
            rationale_codes=["snapshot_nudge", "relapse_path"],
        )
    if route == SupervisorPrimaryRoute.revise_goal_node:
        return SupervisorDecision(
            revise_goal=True,
            primary_route=route,
            rationale_codes=["snapshot_nudge", "goal_revise_path"],
        )
    return SupervisorDecision(
        deliver_micro_action=True,
        primary_route=SupervisorPrimaryRoute.deliver_micro_action_node,
        rationale_codes=["snapshot_nudge", "fallback_micro"],
    )


def apply_goal_rates_to_goals(
    goals: List[AdaptiveGoal],
    rates: Dict[str, float],
) -> List[AdaptiveGoal]:
    out: List[AdaptiveGoal] = []
    for g in goals:
        ng = g.model_copy(deep=True)
        r = rates.get(g.goal_id)
        if r is not None:
            ng.success_rate_7d = r
            ng.success_rate_30d = max(ng.success_rate_30d, r * 0.9)
        out.append(ng)
    return out
