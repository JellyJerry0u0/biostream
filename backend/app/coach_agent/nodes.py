"""
LangGraph 노드 — 책임 분리. 수치/라우팅은 deterministic, 문장은 LLM.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List

from app.coach_agent.context_loader import load_user_context_bundle
from app.coach_agent.deterministic import (
    apply_goal_rates_to_goals,
    build_intervention_skeleton,
    compute_derived_metrics,
    compute_missing_profile_fields,
    deterministic_behavior_patterns,
    pick_snapshot_coach_route,
    supervisor_decide,
    supervisor_decision_for_snapshot_route,
)
from app.coach_agent.llm_provider import CoachLLMProvider, get_coach_llm_provider
from app.coach_agent.memory_store import (
    SessionDictCoachMemoryStore,
    parse_persisted,
    serialize_persisted,
)
from app.coach_agent.schemas import (
    AdaptiveGoal,
    AdherenceSummary,
    BehaviorPattern,
    CoachingMemory,
    DerivedMetrics,
    EpisodicEvent,
    HealthLog,
    SupervisorPrimaryRoute,
    UserProfile,
)
from app.coach_agent.state import CoachAgentState


async def _emit_coach_progress(state: CoachAgentState, step: str, label: str) -> None:
    """코치 모드 전용 진행 표시(tool_status와 동일 채널 패밀리)."""
    sj = state.get("send_json")
    aid = state.get("assistant_msg_id")
    if not sj or not aid:
        return
    try:
        await sj(
            {
                "type": "coach_progress",
                "assistant_message_id": aid,
                "step": step,
                "label": label,
                "status": "running",
            }
        )
    except Exception:
        pass


def _report_excerpt(report_ctx: Dict[str, Any]) -> str:
    if not report_ctx.get("has_report"):
        return ""
    return str(report_ctx.get("summary_text", ""))[:2000]


async def node_load_user_context(state: CoachAgentState) -> Dict[str, Any]:
    session = state["session"]
    db = state["db"]
    uid = session.user_id
    if not uid or not db:
        profile = UserProfile(user_id=uid or 0, nickname="")
        await _emit_coach_progress(state, "loaded_context", "대화 맥락 준비")
        return {
            "user_id": uid or 0,
            "profile": profile.model_dump(mode="json"),
            "recent_health_logs": [],
            "active_goals": [],
            "goal_history": [],
            "episodic_memory": [],
            "coaching_memory": CoachingMemory().model_dump(mode="json"),
            "conversation_history": session.get_history_for_prompt(),
            "missing_info": compute_missing_profile_fields(profile),
        }

    bundle = await load_user_context_bundle(uid, db, session, report_ctx=state.get("report_ctx"))
    prof: UserProfile = bundle["profile"]
    await _emit_coach_progress(state, "loaded_context", "프로필·기록 불러오는 중")
    return {
        "user_id": uid,
        "profile": prof.model_dump(mode="json"),
        "recent_health_logs": bundle["recent_health_logs"],
        "active_goals": bundle["active_goals"],
        "goal_history": bundle["goal_history"],
        "episodic_memory": bundle["episodic_memory"],
        "coaching_memory": bundle["coaching_memory"],
        "conversation_history": bundle["conversation_history"],
        "missing_info": compute_missing_profile_fields(prof),
        "_parsed_goals": bundle["_raw_goals"],
        "_parsed_logs": bundle["_raw_logs"],
        "_checkin_by_goal": bundle["checkin_by_goal"],
    }


async def node_compute_derived_metrics(state: CoachAgentState) -> Dict[str, Any]:
    profile = UserProfile.model_validate(state["profile"])
    raw_logs = state.get("_parsed_logs")
    if raw_logs is None:
        raw_logs = [HealthLog.model_validate(x) for x in state.get("recent_health_logs", [])]

    goals = state.get("_parsed_goals")
    if goals is None:
        goals = [AdaptiveGoal.model_validate(x) for x in state.get("active_goals", [])]

    checkin = state.get("_checkin_by_goal") or {}
    msg = state.get("current_message", "")
    dm, adher = compute_derived_metrics(
        profile,
        raw_logs,
        goals,
        checkin_by_goal=checkin,
        user_message=msg,
    )
    goals2 = apply_goal_rates_to_goals(goals, dm.goal_level_rates)
    await _emit_coach_progress(state, "derived_metrics", "지표·달성률 계산 중")
    return {
        "derived_metrics": dm.model_dump(mode="json"),
        "adherence_summary": adher.model_dump(mode="json"),
        "active_goals": [g.model_dump(mode="json") for g in goals2],
        "_parsed_goals": goals2,
    }


async def node_assess_behavior_patterns(state: CoachAgentState) -> Dict[str, Any]:
    dm = DerivedMetrics.model_validate(state["derived_metrics"])
    adher = AdherenceSummary.model_validate(state["adherence_summary"])
    goals = [AdaptiveGoal.model_validate(x) for x in state.get("active_goals", [])]
    msg = state.get("current_message", "")

    det = deterministic_behavior_patterns(dm, adher, goals, msg)

    llm: CoachLLMProvider = get_coach_llm_provider()
    log_lines = []
    for x in state.get("recent_health_logs", [])[:20]:
        if isinstance(x, dict):
            log_lines.append(
                f"{x.get('log_date')} {x.get('metric_key')}={x.get('value_numeric')}"
            )
    merged = await llm.enrich_behavior_patterns(
        dm.model_dump(),
        log_lines,
        det,
    )
    await _emit_coach_progress(state, "behavior_patterns", "행동 패턴 정리 중")
    return {
        "behavior_patterns": [p.model_dump(mode="json") for p in merged],
    }


async def node_supervisor_route(state: CoachAgentState) -> Dict[str, Any]:
    dm = DerivedMetrics.model_validate(state["derived_metrics"])
    adher = AdherenceSummary.model_validate(state["adherence_summary"])
    goals = [AdaptiveGoal.model_validate(x) for x in state.get("active_goals", [])]

    if state.get("snapshot_nudge_mode"):
        route = pick_snapshot_coach_route(dm, adher, goals)
        dec = supervisor_decision_for_snapshot_route(route)
        await _emit_coach_progress(state, "supervisor", "코칭 방향 선택 중")
        return {"supervisor_decision": dec.model_dump(mode="json")}

    profile = UserProfile.model_validate(state["profile"])
    patterns = [
        BehaviorPattern.model_validate(p) for p in state.get("behavior_patterns", [])
    ]
    dec = supervisor_decide(
        profile,
        dm,
        adher,
        patterns,
        state.get("missing_info") or [],
        state.get("current_message", ""),
        active_goals=goals,
        coaching_hint_weekly=False,
    )
    await _emit_coach_progress(state, "supervisor", "코칭 방향 선택 중")
    return {"supervisor_decision": dec.model_dump(mode="json")}


def _branch(state: CoachAgentState, route: SupervisorPrimaryRoute) -> Dict[str, Any]:
    patterns = [
        BehaviorPattern.model_validate(p) for p in state.get("behavior_patterns", [])
    ]
    goals = [AdaptiveGoal.model_validate(x) for x in state.get("active_goals", [])]
    dm = DerivedMetrics.model_validate(state["derived_metrics"])
    plan = build_intervention_skeleton(
        route,
        patterns,
        goals,
        dm,
        state.get("current_message", ""),
    )
    return {"intervention_plan": plan.model_dump(mode="json")}


async def node_ask_followup_question(state: CoachAgentState) -> Dict[str, Any]:
    return _branch(state, SupervisorPrimaryRoute.ask_followup_question_node)


async def node_revise_goal(state: CoachAgentState) -> Dict[str, Any]:
    return _branch(state, SupervisorPrimaryRoute.revise_goal_node)


async def node_deliver_micro_action(state: CoachAgentState) -> Dict[str, Any]:
    return _branch(state, SupervisorPrimaryRoute.deliver_micro_action_node)


async def node_reinforce_success(state: CoachAgentState) -> Dict[str, Any]:
    return _branch(state, SupervisorPrimaryRoute.reinforce_success_node)


async def node_detect_relapse(state: CoachAgentState) -> Dict[str, Any]:
    return _branch(state, SupervisorPrimaryRoute.detect_relapse_node)


async def node_weekly_reflection(state: CoachAgentState) -> Dict[str, Any]:
    return _branch(state, SupervisorPrimaryRoute.weekly_reflection_node)


async def node_generate_structured_response(state: CoachAgentState) -> Dict[str, Any]:
    await _emit_coach_progress(state, "structured", "맞춤 응답 구성 중")
    llm = get_coach_llm_provider()
    profile = UserProfile.model_validate(state["profile"])
    prof_summary = profile.model_dump_json()[:1500]
    patterns_txt = "\n".join(
        p.get("summary", "") for p in state.get("behavior_patterns", [])[:6]
    )
    structured = await llm.generate_structured_coaching(
        state.get("current_message", ""),
        prof_summary,
        state.get("derived_metrics") or {},
        patterns_txt,
        state.get("intervention_plan") or {},
        _report_excerpt(state.get("report_ctx") or {}),
    )
    dm = state.get("derived_metrics") or {}
    if dm.get("risky_phrase_flags"):
        structured.safety_disclaimer_line = (
            "말씀해 주신 내용은 전문가 상담이 도움이 될 수 있습니다. "
            "응급이 의심되면 가까운 의료기관에 연락해 주세요."
        )
    return {"structured_response": structured.model_dump(mode="json")}


async def node_render_final_response(state: CoachAgentState) -> Dict[str, Any]:
    from app.coach_agent.schemas import StructuredCoachingResponse

    llm = get_coach_llm_provider()
    structured = StructuredCoachingResponse.model_validate(
        state.get("structured_response") or {}
    )
    tone = (state.get("intervention_plan") or {}).get("tone_strategy", "warm")
    text = await llm.render_final_korean(structured, tone)
    await _emit_coach_progress(state, "render", "문장 다듬는 중")
    return {"final_response": text}


async def node_save_memory_and_state(state: CoachAgentState) -> Dict[str, Any]:
    session = state.get("session")
    if not session:
        return {}
    store = SessionDictCoachMemoryStore(session)
    blob = store.load()
    goals, hist, episodic, coaching = parse_persisted(blob)

    goals_new = [AdaptiveGoal.model_validate(x) for x in state.get("active_goals", [])]
    plan = state.get("intervention_plan") or {}
    inter_type = plan.get("intervention_type", "")

    # coaching memory 휴리스틱 업데이트
    msg = state.get("current_message", "")
    if len(msg) < 25:
        coaching.last_user_message_length_bucket = "short"
    elif len(msg) < 120:
        coaching.last_user_message_length_bucket = "medium"
    else:
        coaching.last_user_message_length_bucket = "long"
    coaching.last_intervention_type = inter_type
    if inter_type in ("goal_downshift", "single_micro_action"):
        coaching.prefers_smaller_goals = True

    episodic.append(
        EpisodicEvent(
            event_id=str(uuid.uuid4()),
            occurred_at=datetime.now(timezone.utc),
            kind="intervention",
            summary=f"{inter_type}: {(plan.get('reasoning_summary') or '')[:120]}",
            related_goal_ids=plan.get("target_goal_ids") or [],
            intervention_type=inter_type,
        )
    )

    blob2 = serialize_persisted(goals_new, hist, episodic[-40:], coaching)
    blob2["goal_history"] = [h.model_dump(mode="json") for h in hist]
    store.save(blob2)
    await _emit_coach_progress(state, "saved", "준비 완료")
    return {}


def route_supervisor(state: CoachAgentState) -> str:
    raw = state.get("supervisor_decision") or {}
    return raw.get("primary_route", SupervisorPrimaryRoute.deliver_micro_action_node.value)
