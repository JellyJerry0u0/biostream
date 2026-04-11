"""
정량 근거 확보 모듈
- preload_quant_evidence: 섹션별 grounded/estimated 정량 근거 로드
"""

from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, Any, List, Set, Optional, Tuple

from app.services.quant_evidence_retriever import get_grouped_stats, get_grouped_stats_multi

from .report_constants import (
    ReportState,
    UI_OUTCOME_TO_QUANT_MAPPED,
    SECTION_OUTCOME_CANDIDATES,
    LIFESTYLE_SECTIONS,
)
from .report_formatters import (
    score_outcome_for_selection,
    timeframe_days_to_label,
    select_top_timeframes,
    calculate_estimated_stats,
)


def _safe_get_grouped_stats(outcome: str) -> Optional[Dict[str, Any]]:
    try:
        return get_grouped_stats(outcome, exclude_suspicious=True)
    except Exception:
        return None


def _fetch_goal_outcome_row(ui_outcome: str) -> Optional[Tuple[str, Dict[str, Any], float]]:
    quant_outcome_list = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
    if not quant_outcome_list:
        return None
    try:
        stats = get_grouped_stats_multi(quant_outcome_list, exclude_suspicious=True)
        if stats and stats.get("timeframe_groups"):
            score = score_outcome_for_selection(stats)
            if score > 0:
                return (ui_outcome, stats, score)
    except Exception as e:
        print(f"    ⚠️ {ui_outcome} 검색 실패: {e}")
    return None


def preload_quant_evidence(state: ReportState) -> ReportState:
    """섹션별 정량 근거 먼저 확보 (grounded 또는 estimated)"""
    print("[PreloadQuantEvidence] 정량 근거 확보 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})

    quant_results = {}

    # D. Quant fallback 안정화: available outcomes 수집
    available_quant_outcomes: Set[str] = set()
    all_candidate_outcomes: Set[str] = set()
    for section in sections:
        qs = "lifestyle" if section in LIFESTYLE_SECTIONS else section
        if section == "summary":
            continue  # summary는 정량 근거 없음 (설문 기반 5각형 점수만 사용)
        if section == "goals":
            outcomes = survey.get("outcomes", [])
            for ui_outcome in outcomes:
                quant_outcomes = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
                all_candidate_outcomes.update(quant_outcomes)
        else:
            candidates = SECTION_OUTCOME_CANDIDATES.get(qs, [])
            all_candidate_outcomes.update(candidates)

    # 병렬로 available outcomes 수집
    outcome_list = list(all_candidate_outcomes)
    with ThreadPoolExecutor(max_workers=min(8, len(outcome_list) or 1)) as ex:
        futures = {ex.submit(get_grouped_stats, o, True): o for o in outcome_list}
        for future in as_completed(futures):
            try:
                stats = future.result()
                if stats and stats.get("timeframe_groups"):
                    available_quant_outcomes.add(futures[future])
            except Exception:
                pass

    print(f"  📊 Available quant outcomes: {len(available_quant_outcomes)}개 ({sorted(list(available_quant_outcomes))[:10]})")

    used_outcomes: Set[str] = set()
    used_timeframe_labels: Dict[str, int] = {}

    for section in sections:
        if section == "summary":
            continue  # summary는 정량 근거 없음
        quant_section = "lifestyle" if section in LIFESTYLE_SECTIONS else section
        if quant_section in quant_results:
            quant_results[section] = quant_results[quant_section]
            print(f"\n  [{section}] quant 공유 (from {quant_section})")
            continue

        print(f"\n  [{quant_section}] 정량 근거 검색 시작")
        section_quant: Dict[str, Any] = {
            "mode": "estimated",
            "selected_outcomes": [],
            "stats_by_outcome": {},
            "quant_refs": [],
        }

        if section == "goals":
            _load_goals_quant(survey, section_quant, used_outcomes, used_timeframe_labels)
        else:
            _load_section_quant(
                quant_section, survey, section_quant,
                used_outcomes, used_timeframe_labels, available_quant_outcomes,
            )

        quant_results[quant_section] = section_quant
        quant_results[section] = section_quant

    print(f"\n✅ [PreloadQuantEvidence] 완료 - {len(quant_results)}개 섹션")
    return {**state, "quant_evidence_results": quant_results}


def _load_goals_quant(
    survey: dict,
    section_quant: dict,
    used_outcomes: Set[str],
    used_timeframe_labels: Dict[str, int],
) -> None:
    """goals 섹션 정량 근거"""
    outcomes = survey.get("outcomes", [])
    outcome_scores: List[tuple] = []

    if outcomes:
        max_w = min(8, len(outcomes))
        with ThreadPoolExecutor(max_workers=max_w) as ex:
            futures = {ex.submit(_fetch_goal_outcome_row, ui): ui for ui in outcomes}
            for fut in as_completed(futures):
                row = fut.result()
                if row:
                    outcome_scores.append(row)

    outcome_scores.sort(key=lambda x: x[2], reverse=True)
    selected_outcomes_data = outcome_scores[:2]

    if not selected_outcomes_data:
        return

    section_quant["mode"] = "grounded"
    section_quant["selected_outcomes"] = [o for o, _, _ in selected_outcomes_data]

    for ui_outcome, _, _ in selected_outcomes_data:
        for qo in UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, []):
            used_outcomes.add(qo)

    for ui_outcome, stats, _ in selected_outcomes_data:
        _store_outcome_stats(
            ui_outcome, stats, section_quant, used_outcomes, used_timeframe_labels,
        )

    total_tf = sum(
        len(select_top_timeframes(s.get("timeframe_groups", {}), max_count=2))
        for _, s, _ in selected_outcomes_data
    )
    print(f"    ✅ {len(selected_outcomes_data)}개 outcome 선택 → grounded (총 {total_tf}개 timeframe)")


def _load_section_quant(
    section: str,
    survey: dict,
    section_quant: dict,
    used_outcomes: Set[str],
    used_timeframe_labels: Dict[str, int],
    available_quant_outcomes: Set[str],
) -> None:
    """일반 섹션 정량 근거"""
    candidates = SECTION_OUTCOME_CANDIDATES.get(section, [])
    outcome_scores: List[tuple] = []

    if candidates:
        max_w = min(8, len(candidates))
        with ThreadPoolExecutor(max_workers=max_w) as ex:
            futures = {ex.submit(_safe_get_grouped_stats, oc): oc for oc in candidates}
            for fut in as_completed(futures):
                outcome = futures[fut]
                stats = fut.result()
                if stats and stats.get("timeframe_groups"):
                    score = score_outcome_for_selection(stats)
                    if score > 0:
                        outcome_scores.append((outcome, stats, score))

    outcome_scores.sort(key=lambda x: x[2], reverse=True)
    filtered = [(o, s, sc * 0.9 if o in used_outcomes else sc) for o, s, sc in outcome_scores]
    filtered.sort(key=lambda x: x[2], reverse=True)
    selected_outcomes_data = filtered[:2]

    if selected_outcomes_data:
        section_quant["mode"] = "grounded"
        section_quant["selected_outcomes"] = [o for o, _, _ in selected_outcomes_data]
        total_timeframes = 0
        for outcome, stats, _ in selected_outcomes_data:
            total_timeframes += _store_outcome_stats(
                outcome, stats, section_quant, used_outcomes, used_timeframe_labels,
            )
        print(f"    ✅ {len(selected_outcomes_data)}개 outcome 선택 → grounded (총 {total_timeframes}개 timeframe)")
    else:
        outcomes = survey.get("outcomes", [])
        all_quant = []
        for ui_outcome in outcomes:
            all_quant.extend(UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, []))
        filtered_candidates = [c for c in all_quant if c in available_quant_outcomes]
        if filtered_candidates:
            estimated = calculate_estimated_stats(filtered_candidates)
            if estimated:
                section_quant["mode"] = "estimated"
                section_quant["selected_outcomes"] = filtered_candidates[:2]
                section_quant["stats_by_outcome"]["estimated"] = estimated
                print(f"    ⚠️ grounded 없음 → estimated ({estimated['timeframe_label']}, {estimated['median']:.1f}%)")
            else:
                print(f"    ⚠️ 정량 근거 없음 (estimated 실패, narrative만 사용)")
        else:
            print(f"    ⚠️ 정량 근거 없음 (available outcomes 없음, narrative만 사용)")


def _store_outcome_stats(
    outcome: str,
    stats: dict,
    section_quant: dict,
    used_outcomes: Set[str],
    used_timeframe_labels: Dict[str, int],
) -> int:
    """outcome stats를 section_quant에 저장, 선택된 timeframe 수 반환"""
    timeframe_groups = stats.get("timeframe_groups", {})
    tf_scores = {}
    for tf_days, group in timeframe_groups.items():
        tf_label = timeframe_days_to_label(tf_days)
        usage = used_timeframe_labels.get(tf_label, 0)
        if usage >= 2:
            continue
        card_count = len(group.get("cards", []))
        tf_scores[tf_days] = card_count / (1 + usage)
    if tf_scores:
        sorted_tfs = sorted(tf_scores.items(), key=lambda x: x[1], reverse=True)
        selected_tfs = [tf for tf, _ in sorted_tfs[:2]]
    else:
        selected_tfs = select_top_timeframes(timeframe_groups, max_count=2)

    used_outcomes.add(outcome)
    for tf_days in selected_tfs:
        tf_label = timeframe_days_to_label(tf_days)
        used_timeframe_labels[tf_label] = used_timeframe_labels.get(tf_label, 0) + 1

    filtered_groups = {tf: timeframe_groups[tf] for tf in selected_tfs if tf in timeframe_groups}
    section_quant["stats_by_outcome"][outcome] = {**stats, "timeframe_groups": filtered_groups}

    for tf_days in selected_tfs:
        if tf_days in timeframe_groups:
            for card_dict in timeframe_groups[tf_days].get("cards", []):
                section_quant["quant_refs"].append({
                    "point_id": f"{card_dict.get('chunk_id', '')}__{card_dict.get('row_uid', '')}",
                    "paper_id": card_dict.get("paper_id", ""),
                    "title": card_dict.get("title", "") or "",
                    "chunk_id": card_dict.get("chunk_id", ""),
                    "outcome_mapped": card_dict.get("outcome_mapped", ""),
                    "timeframe_days": tf_days,
                    "effect_signed_value": card_dict.get("effect_signed_value"),
                    "effect_unit": card_dict.get("effect_unit_filled", "%"),
                    "p_value": card_dict.get("p_value_num"),
                    "p_label": card_dict.get("p_label", ""),
                    "source_snippet": card_dict.get("source_snippet", ""),
                })
    return len(selected_tfs)
