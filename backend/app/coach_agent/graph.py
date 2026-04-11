"""
코치 에이전트 LangGraph 조립.

흐름: load → metrics → patterns → supervisor → (분기) → structured → final → save → END
"""

from __future__ import annotations

from langgraph.graph import END, StateGraph

from app.coach_agent.nodes import (
    node_ask_followup_question,
    node_assess_behavior_patterns,
    node_compute_derived_metrics,
    node_deliver_micro_action,
    node_detect_relapse,
    node_generate_structured_response,
    node_load_user_context,
    node_render_final_response,
    node_reinforce_success,
    node_revise_goal,
    node_save_memory_and_state,
    node_supervisor_route,
    node_weekly_reflection,
    route_supervisor,
)
from app.coach_agent.state import CoachAgentState


def build_coach_agent_graph():
    g = StateGraph(CoachAgentState)

    g.add_node("load_user_context", node_load_user_context)
    g.add_node("compute_derived_metrics", node_compute_derived_metrics)
    g.add_node("assess_behavior_patterns", node_assess_behavior_patterns)
    g.add_node("supervisor_route", node_supervisor_route)

    g.add_node("ask_followup_question_node", node_ask_followup_question)
    g.add_node("revise_goal_node", node_revise_goal)
    g.add_node("deliver_micro_action_node", node_deliver_micro_action)
    g.add_node("reinforce_success_node", node_reinforce_success)
    g.add_node("detect_relapse_node", node_detect_relapse)
    g.add_node("weekly_reflection_node", node_weekly_reflection)

    g.add_node("generate_structured_response", node_generate_structured_response)
    g.add_node("render_final_response", node_render_final_response)
    g.add_node("save_memory_and_state", node_save_memory_and_state)

    g.set_entry_point("load_user_context")
    g.add_edge("load_user_context", "compute_derived_metrics")
    g.add_edge("compute_derived_metrics", "assess_behavior_patterns")
    g.add_edge("assess_behavior_patterns", "supervisor_route")

    branches = {
        "ask_followup_question_node": "ask_followup_question_node",
        "revise_goal_node": "revise_goal_node",
        "deliver_micro_action_node": "deliver_micro_action_node",
        "reinforce_success_node": "reinforce_success_node",
        "detect_relapse_node": "detect_relapse_node",
        "weekly_reflection_node": "weekly_reflection_node",
    }
    g.add_conditional_edges("supervisor_route", route_supervisor, branches)

    for name in branches.values():
        g.add_edge(name, "generate_structured_response")

    g.add_edge("generate_structured_response", "render_final_response")
    g.add_edge("render_final_response", "save_memory_and_state")
    g.add_edge("save_memory_and_state", END)

    return g.compile()
