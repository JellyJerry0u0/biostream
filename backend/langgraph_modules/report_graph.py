"""
LangGraph 기반 리포트 생성 워크플로우 (Quant-First 아키텍처)
정량 근거를 먼저 확보하고, 그를 중심으로 서술을 생성하는 구조

노드 흐름:
1. LoadSurvey
2. PlanSections
2.5. DeriveUserProfile
3. PreloadQuantEvidence
4. BuildQueries
5. RetrieveNarrativeEvidence
5.5. ExtractClaims (rule-based)
6. WriteSectionCards
6.5. ValidateCards
7. AssembleReport
8. SaveReport
"""

import os
import sys
import traceback
from typing import Dict, Any, List, Optional

# 패키지 import
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

# 경로 설정
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.append(backend_dir)

from tools.survey_tool import get_survey
from tools.qdrant_search import qdrant_search
from tools.report_store import save_report
from tools.schemas import QdrantSearchInput

from app.services.quant_evidence_retriever import (
    get_grouped_stats, get_grouped_stats_multi,
)

# ── 서브모듈 import ──
from .report_constants import (
    ReportState,
    OUTCOME_LABELS,
    UI_OUTCOME_TO_QUANT_MAPPED,
    OUTCOME_TO_NARRATIVE_TOPICS,
    SECTION_OUTCOME_CANDIDATES,
    SECTION_CARD_TYPE_KEYWORDS,
    SECTION_TITLES,
)
from .report_llm import get_llm_call_count
from .report_formatters import (
    map_outcomes_to_topics,
    timeframe_days_to_label,
    calculate_user_profile_derived,
    format_user_profile_for_prompt,
    score_outcome_for_selection,
    select_top_timeframes,
    calculate_estimated_stats,
)
from .report_cards import (
    generate_section_cards,
    generate_lifestyle_cards,
    get_lifestyle_subsection_keys,
    create_template_based_subsection_cards,
    build_dual_queries,
    extract_keyword_based_sentences,
    validate_section_cards,
)

# ── 하위 호환 re-export ──
# 테스트 파일에서 from langgraph_modules.report_graph import X 로 사용 중인 심볼:
#   ReportState, SECTION_CARD_TYPE_KEYWORDS, OUTCOME_TO_NARRATIVE_TOPICS,
#   map_outcomes_to_topics → 위 import에서 자동 re-export
_extract_keyword_based_sentences = extract_keyword_based_sentences  # noqa: F841


# ════════════════════════════════════════════════════════════════
#  노드 1: LoadSurvey
# ════════════════════════════════════════════════════════════════

def load_survey(state: ReportState) -> ReportState:
    """설문 데이터 로드"""
    user_id = state["user_id"]
    lifestyle_id = state.get("lifestyle_id")
    print(f"[LoadSurvey] user_id={user_id}, lifestyle_id={lifestyle_id}")

    try:
        survey = get_survey(user_id, lifestyle_id=lifestyle_id)
        if "error" in survey:
            print(f"⚠️ [LoadSurvey] 오류: {survey['error']}")
            return {**state, "survey": None}
        print("✅ [LoadSurvey] 설문 데이터 로드 완료")
        return {**state, "survey": survey}
    except Exception as e:
        print(f"❌ [LoadSurvey] 실패: {e}")
        return {**state, "survey": None}


# ════════════════════════════════════════════════════════════════
#  노드 2: PlanSections
# ════════════════════════════════════════════════════════════════

def plan_sections(state: ReportState) -> ReportState:
    """생성할 섹션 계획"""
    print("[PlanSections] 섹션 계획 시작")
    survey = state.get("survey")
    if not survey:
        return {**state, "active_sections": []}

    sections = ["goals"]
    if survey.get("sleep_hours_weekday") is not None or survey.get("sleep_quality_score") is not None:
        sections.append("sleep")
    if survey.get("uv_exposure_10to16") or survey.get("sunscreen_frequency"):
        sections.append("uv")
    if survey.get("drinking_days_per_week") or survey.get("smoking_status") or survey.get("stress_score"):
        sections.append("lifestyle")
    if survey.get("aerobic_weekly") or survey.get("resistance_weekly"):
        sections.append("activity")

    print(f"✅ [PlanSections] 섹션 계획 완료: {sections}")
    return {**state, "active_sections": sections}


# ════════════════════════════════════════════════════════════════
#  노드 2.5: DeriveUserProfile
# ════════════════════════════════════════════════════════════════

def derive_user_profile(state: ReportState) -> ReportState:
    """사용자 프로필 파생 지표 계산"""
    print("[DeriveUserProfile] 사용자 프로필 계산 시작")
    user_id = state.get("user_id")
    survey = state.get("survey", {})

    if not user_id or not survey:
        print("  ⚠️ user_id 또는 survey 없음, 프로필 계산 스킵")
        return {**state, "user_profile": {}}

    try:
        user_profile = calculate_user_profile_derived(user_id, survey)
        profile_summary = format_user_profile_for_prompt(user_profile)
        print(f"  ✅ 사용자 프로필 계산 완료: {profile_summary}")
        return {**state, "user_profile": user_profile}
    except Exception as e:
        print(f"  ⚠️ 사용자 프로필 계산 실패: {e}")
        return {**state, "user_profile": {}}


# ════════════════════════════════════════════════════════════════
#  노드 3: PreloadQuantEvidence (헬퍼)
# ════════════════════════════════════════════════════════════════

class _QuantHelper:
    """PreloadQuantEvidence 내부 로직을 깔끔하게 분리하기 위한 네임스페이스"""

    @staticmethod
    def _collect_outcome_scores(outcome_list, search_fn, used_outcomes):
        """outcome 후보들의 점수를 수집"""
        scores = []
        for outcome in outcome_list:
            try:
                stats = search_fn(outcome)
                if stats and stats.get("timeframe_groups"):
                    score = score_outcome_for_selection(stats)
                    if score > 0:
                        scores.append((outcome, stats, score))
            except Exception:
                continue
        return scores

    @staticmethod
    def _select_timeframes_with_dedup(
        timeframe_groups, used_timeframe_labels, max_count=2,
    ):
        """겹침을 최소화하며 timeframe 선택"""
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
            return [tf for tf, _ in sorted_tfs[:max_count]]
        return select_top_timeframes(timeframe_groups, max_count=max_count)

    @staticmethod
    def _store_outcome_data(
        outcome, stats, section_quant, used_outcomes,
        used_timeframe_labels,
    ):
        """outcome 데이터를 section_quant에 저장"""
        timeframe_groups = stats.get("timeframe_groups", {})
        selected_tfs = _QuantHelper._select_timeframes_with_dedup(
            timeframe_groups, used_timeframe_labels,
        )

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


def _preload_goals_quant(survey, section_quant, used_outcomes, used_timeframe_labels):
    """goals 섹션 정량 근거"""
    outcomes = survey.get("outcomes", [])
    outcome_scores = []

    for ui_outcome in outcomes:
        quant_list = UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, [])
        if not quant_list:
            continue
        try:
            stats = get_grouped_stats_multi(quant_list, exclude_suspicious=True)
            if stats and stats.get("timeframe_groups"):
                score = score_outcome_for_selection(stats)
                if score > 0:
                    outcome_scores.append((ui_outcome, stats, score))
        except Exception as e:
            print(f"    ⚠️ {ui_outcome} 검색 실패: {e}")

    outcome_scores.sort(key=lambda x: x[2], reverse=True)
    selected = outcome_scores[:2]

    if selected:
        section_quant["mode"] = "grounded"
        section_quant["selected_outcomes"] = [o for o, _, _ in selected]

        for ui_outcome, _, _ in selected:
            for qo in UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, []):
                used_outcomes.add(qo)

        total_tf = 0
        for ui_outcome, stats, _ in selected:
            total_tf += _QuantHelper._store_outcome_data(
                ui_outcome, stats, section_quant, used_outcomes, used_timeframe_labels,
            )
        print(f"    ✅ {len(selected)}개 outcome 선택 → grounded (총 {total_tf}개 timeframe)")


def _preload_section_quant(
    section, survey, section_quant,
    used_outcomes, used_timeframe_labels, available_quant_outcomes,
):
    """일반 섹션 정량 근거"""
    candidates = SECTION_OUTCOME_CANDIDATES.get(section, [])
    outcome_scores = []

    for outcome in candidates:
        try:
            stats = get_grouped_stats(outcome, exclude_suspicious=True)
            if stats and stats.get("timeframe_groups"):
                score = score_outcome_for_selection(stats)
                if score > 0:
                    outcome_scores.append((outcome, stats, score))
        except Exception:
            continue

    # 겹침 페널티
    filtered = []
    for outcome, stats, score in outcome_scores:
        adj = score * 0.9 if outcome in used_outcomes else score
        filtered.append((outcome, stats, adj))
    filtered.sort(key=lambda x: x[2], reverse=True)
    selected = filtered[:2]

    if selected:
        section_quant["mode"] = "grounded"
        section_quant["selected_outcomes"] = [o for o, _, _ in selected]

        total_tf = 0
        for outcome, stats, _ in selected:
            total_tf += _QuantHelper._store_outcome_data(
                outcome, stats, section_quant, used_outcomes, used_timeframe_labels,
            )
        print(f"    ✅ {len(selected)}개 outcome 선택 → grounded (총 {total_tf}개 timeframe)")
    else:
        # estimated fallback
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
                print("    ⚠️ 정량 근거 없음 (estimated 실패)")
        else:
            print("    ⚠️ 정량 근거 없음 (available outcomes 없음)")


def preload_quant_evidence(state: ReportState) -> ReportState:
    """섹션별 정량 근거 확보"""
    print("[PreloadQuantEvidence] 정량 근거 확보 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    quant_results: Dict[str, Dict[str, Any]] = {}

    # available outcomes 수집
    available_quant_outcomes = set()
    all_candidate_outcomes = set()
    for section in sections:
        if section == "goals":
            for ui_outcome in survey.get("outcomes", []):
                all_candidate_outcomes.update(UI_OUTCOME_TO_QUANT_MAPPED.get(ui_outcome, []))
        else:
            all_candidate_outcomes.update(SECTION_OUTCOME_CANDIDATES.get(section, []))

    for outcome in all_candidate_outcomes:
        try:
            stats = get_grouped_stats(outcome, exclude_suspicious=True)
            if stats and stats.get("timeframe_groups"):
                available_quant_outcomes.add(outcome)
        except Exception:
            pass

    print(f"  📊 Available quant outcomes: {len(available_quant_outcomes)}개")

    used_outcomes: set = set()
    used_timeframe_labels: Dict[str, int] = {}

    for section in sections:
        print(f"\n  [{section}] 정량 근거 검색 시작")
        section_quant: Dict[str, Any] = {
            "mode": "estimated",
            "selected_outcomes": [],
            "stats_by_outcome": {},
            "quant_refs": [],
        }

        if section == "goals":
            _preload_goals_quant(survey, section_quant, used_outcomes, used_timeframe_labels)
        else:
            _preload_section_quant(
                section, survey, section_quant,
                used_outcomes, used_timeframe_labels, available_quant_outcomes,
            )

        quant_results[section] = section_quant

    print(f"\n✅ [PreloadQuantEvidence] 완료 - {len(quant_results)}개 섹션")
    return {**state, "quant_evidence_results": quant_results}


# ════════════════════════════════════════════════════════════════
#  노드 4: BuildQueries
# ════════════════════════════════════════════════════════════════

def build_queries(state: ReportState) -> ReportState:
    """섹션별 카드 타입별 검색 쿼리 생성"""
    print("[BuildQueries] 카드별 검색 쿼리 생성 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    quant_results = state.get("quant_evidence_results", {})
    user_profile = state.get("user_profile", {})

    section_queries: Dict[str, Dict[str, str]] = {}

    for section in sections:
        section_quant = quant_results.get(section, {})
        selected_outcomes = section_quant.get("selected_outcomes", [])

        # 사용자 정보 키워드
        user_keywords = []
        if user_profile.get("gender"):
            gender_label = "남성" if user_profile["gender"].lower() in ["male", "m", "남성", "남"] else "여성"
            user_keywords.append(gender_label)
        if user_profile.get("age_bucket"):
            user_keywords.append(user_profile["age_bucket"])
        if user_profile.get("bmi_category") in ["과체중", "비만"]:
            user_keywords.append("대사")

        # timeframe 키워드
        tf_label = None
        for outcome_stats in section_quant.get("stats_by_outcome", {}).values():
            if isinstance(outcome_stats, dict) and "timeframe_groups" in outcome_stats:
                timeframes = list(outcome_stats["timeframe_groups"].keys())[:1]
                if timeframes:
                    tf_label = timeframe_days_to_label(timeframes[0])
                    break

        outcome_keywords = [OUTCOME_LABELS.get(o, o) for o in selected_outcomes] if selected_outcomes else []

        # 카드별 쿼리
        _Q = {
            "goals": {
                "problem": lambda: f"{' '.join([OUTCOME_LABELS.get(o, o) for o in survey.get('outcomes', [])])} 피부 문제 상태",
                "cause": lambda: f"{' '.join([OUTCOME_LABELS.get(o, o) for o in survey.get('outcomes', [])])} 원인 메커니즘",
                "action": lambda: f"{' '.join([OUTCOME_LABELS.get(o, o) for o in survey.get('outcomes', [])])} 개선 방법",
            },
            "sleep": {
                "problem": lambda: f"수면 부족 단기간 피부 장벽 수분 {' '.join(outcome_keywords)}",
                "cause": lambda: f"수면 파편화 코르티솔 염증 피부 {' '.join(outcome_keywords)}",
                "action": lambda: f"수면 연장 개입 시험 피부 {' '.join(outcome_keywords)} {tf_label or ''}",
            },
            "uv": {
                "problem": lambda: f"자외선 노출 사진노화 색소 주름 {' '.join(outcome_keywords)}",
                "cause": lambda: f"UV 자외선 멜라닌 콜라겐 분해 {' '.join(outcome_keywords)}",
                "action": lambda: f"선크림 자외선 차단 개입 {' '.join(outcome_keywords)} {tf_label or ''}",
            },
            "lifestyle": {
                "problem": lambda: f"음주 흡연 스트레스 피부 염증 {' '.join(outcome_keywords)}",
                "cause": lambda: f"알코올 니코틴 코르티솔 염증 신호 피부 {' '.join(outcome_keywords)}",
                "action": lambda: f"생활습관 개선 개입 피부 {' '.join(outcome_keywords)} {tf_label or ''}",
            },
            "activity": {
                "problem": lambda: f"운동 부족 대사 피부 탄력 {' '.join(outcome_keywords)}",
                "cause": lambda: f"신진대사 콜라겐 합성 피부 {' '.join(outcome_keywords)}",
                "action": lambda: f"운동 개입 피부 건강 {' '.join(outcome_keywords)} {tf_label or ''}",
            },
        }

        queries_by_card = {}
        if section in _Q:
            for card_type, fn in _Q[section].items():
                queries_by_card[card_type] = fn()

        # 사용자 키워드 soft 추가
        if user_keywords:
            for card_type in queries_by_card:
                queries_by_card[card_type] += f" {user_keywords[0]}"

        section_queries[section] = queries_by_card

    print("✅ [BuildQueries] 카드별 쿼리 생성 완료")
    return {**state, "section_queries": section_queries}


# ════════════════════════════════════════════════════════════════
#  노드 5: RetrieveNarrativeEvidence
# ════════════════════════════════════════════════════════════════

def retrieve_narrative_evidence(state: ReportState) -> ReportState:
    """카드 타입별 원문 근거 검색 (다단계 fallback)"""
    print("[RetrieveNarrativeEvidence] 카드별 원문 근거 검색 시작")
    sections = state.get("active_sections", [])
    section_queries = state.get("section_queries", {})
    survey = state.get("survey", {})

    narrative_results: Dict[str, Dict[str, list]] = {}

    for section in sections:
        queries_by_card = section_queries.get(section, {})
        if not queries_by_card:
            narrative_results[section] = {"problem": [], "cause": [], "action": []}
            continue

        section_results: Dict[str, list] = {}
        topics = None
        if section == "goals":
            outcomes = survey.get("outcomes", [])
            topics = map_outcomes_to_topics(outcomes, include_fallback=True)
            print(f"  [{section}] UI outcomes {outcomes} → narrative topics {topics}")
        elif section == "activity":
            topics = ["exercise"]

        for card_type in ["problem", "cause", "action"]:
            korean_query = queries_by_card.get(card_type, "")
            if not korean_query:
                section_results[card_type] = []
                continue

            section_quant = state.get("quant_evidence_results", {}).get(section, {})
            selected_outcomes = section_quant.get("selected_outcomes", [])
            ok = [OUTCOME_LABELS.get(o, o) for o in selected_outcomes] if selected_outcomes else []
            user_profile = state.get("user_profile", {})

            dual_queries = build_dual_queries(section, card_type, survey, user_profile, ok)
            english_query = dual_queries[0] if dual_queries else korean_query

            items = []
            seen_ids = set()

            # 1차: 영어 + topics
            items, seen_ids = _search_qdrant(english_query, topics, 5, 50, 0.2, items, seen_ids)
            if items:
                top_s = f"{items[0].score:.3f}" if hasattr(items[0], 'score') else "N/A"
                print(f"  [{section}.{card_type}] 1차 영어 검색: {len(items)}개 (top={top_s})")

            # 1.5차: topics=None
            if len(items) == 0 and topics:
                items, seen_ids = _search_qdrant(english_query, None, 5, 50, 0.2, items, seen_ids)
                if items:
                    print(f"  [{section}.{card_type}] 1.5차 (topics=None): {len(items)}개")

            # 2차: 한국어 보충
            if len(items) < 3:
                items, seen_ids = _search_qdrant(korean_query, topics, 5, 50, 0.2, items, seen_ids, max_total=5)
                if items:
                    print(f"  [{section}.{card_type}] 2차 한국어: 총 {len(items)}개")

            # 3차: min_score 완화
            if len(items) == 0:
                items, seen_ids = _search_qdrant(english_query, topics, 10, 80, 0.12, items, seen_ids, max_total=5)
                if items:
                    print(f"  [{section}.{card_type}] 3차 fallback: {len(items)}개")
                else:
                    print(f"  [{section}.{card_type}] 모든 검색 실패: 0개")

            section_results[card_type] = items
        narrative_results[section] = section_results

    print("✅ [RetrieveNarrativeEvidence] 완료")
    return {**state, "narrative_evidence": narrative_results}


def _search_qdrant(query, topics, top_k, candidate_k, min_score, items, seen_ids, max_total=None):
    """Qdrant 검색 헬퍼"""
    try:
        result = qdrant_search(QdrantSearchInput(
            query=query, top_k=top_k, topics=topics,
            section_norm=None, candidate_k=candidate_k, min_score=min_score,
        ))
        for item in result.items:
            if item.chunk_id not in seen_ids:
                if max_total and len(items) >= max_total:
                    break
                items.append(item)
                seen_ids.add(item.chunk_id)
    except Exception as e:
        print(f"  ⚠️ Qdrant 검색 실패: {e}")
    return items, seen_ids


# ════════════════════════════════════════════════════════════════
#  노드 5.5: ExtractClaims (rule-based)
# ════════════════════════════════════════════════════════════════

def extract_claims(state: ReportState) -> ReportState:
    """narrative evidence를 구조화된 claims로 변환 (rule-based)"""
    print("[ExtractClaims] 근거 구조화 시작 (rule-based)")
    sections = state.get("active_sections", [])
    narrative_evidence = state.get("narrative_evidence", {})

    extracted_claims: Dict[str, Dict[str, list]] = {}

    for section in sections:
        section_evidence = narrative_evidence.get(section, {})
        if not section_evidence:
            extracted_claims[section] = {"problem": [], "cause": [], "action": []}
            continue

        section_claims: Dict[str, list] = {}
        for card_type in ["problem", "cause", "action"]:
            evidence_items = section_evidence.get(card_type, [])
            if not evidence_items:
                section_claims[card_type] = []
                continue

            keywords = SECTION_CARD_TYPE_KEYWORDS.get(section, {}).get(card_type, [])
            claims = []
            for item in evidence_items[:2]:
                selected = extract_keyword_based_sentences(item.text, keywords, max_sentences=2)
                if selected:
                    claim_text = " ".join(selected)
                    if len(claim_text) > 50:
                        claims.append({
                            "claim": claim_text[:150],
                            "support": [{
                                "chunk_id": item.chunk_id,
                                "support_text": " ".join(selected)[:200],
                                "why_relevant": f"키워드 기반 추출 ({', '.join(keywords[:3])})",
                            }],
                            "survey_hooks": [],
                            "profile_hooks": [],
                        })
            section_claims[card_type] = claims[:2]
        extracted_claims[section] = section_claims

    print("✅ [ExtractClaims] 완료 (rule-based)")
    return {**state, "extracted_claims": extracted_claims}


# ════════════════════════════════════════════════════════════════
#  노드 6: WriteSectionCards
# ════════════════════════════════════════════════════════════════

def write_section_cards(state: ReportState) -> ReportState:
    """섹션별 4카드 JSON 생성"""
    print("[WriteSectionCards] 카드 생성 시작")
    sections = state.get("active_sections", [])
    survey = state.get("survey", {})
    quant_results = state.get("quant_evidence_results", {})
    extracted_claims = state.get("extracted_claims", {})
    user_profile = state.get("user_profile", {})

    retry_sections = state.get("retry_sections", [])
    existing_cards = state.get("section_cards", {})

    if retry_sections:
        print(f"  🔄 재시도 섹션: {retry_sections}")
        sections_to_process = retry_sections
        section_cards = existing_cards.copy()
    else:
        sections_to_process = sections
        section_cards: Dict[str, list] = {}

    for section in sections_to_process:
        print(f"\n  [{section}] 카드 생성 중...")
        if section == "lifestyle":
            subsections = get_lifestyle_subsection_keys(survey)
            if subsections:
                print(f"  [{section}] 하위 섹션: {subsections} (LLM 통합 호출)")
                # 1회 LLM 호출로 모든 서브섹션 카드 생성 (실패 시 서브섹션별 템플릿 fallback)
                lifestyle_result = generate_lifestyle_cards(
                    survey, quant_results, extracted_claims, user_profile, state,
                )
                for sub_key in subsections:
                    section_cards[f"{section}.{sub_key}"] = lifestyle_result.get(sub_key, [])
                section_cards[section] = section_cards.get(f"{section}.{subsections[0]}", [])
            else:
                section_cards[section] = generate_section_cards(
                    section, survey, quant_results, extracted_claims, user_profile, state,
                )
        else:
            section_cards[section] = generate_section_cards(
                section, survey, quant_results, extracted_claims, user_profile, state,
            )

    print(f"\n✅ [WriteSectionCards] 완료")
    print(f"📊 [LLMBudget] 총 LLM 호출 횟수: {get_llm_call_count()}회")

    if retry_sections:
        state["retry_needed"] = False
        state["retry_sections"] = []

    quality_flags = state.get("quality_flags", {})
    return {**state, "section_cards": section_cards, "quality_flags": quality_flags}


# ════════════════════════════════════════════════════════════════
#  노드 6.5: ValidateCards
# ════════════════════════════════════════════════════════════════

def validate_cards(state: ReportState) -> ReportState:
    """생성된 카드 품질 검증 및 재시도"""
    print("[ValidateCards] 카드 품질 검증 시작")
    sections = state.get("active_sections", [])
    section_cards = state.get("section_cards", {})
    survey = state.get("survey", {})
    user_profile = state.get("user_profile", {})
    extracted_claims = state.get("extracted_claims", {})

    retry_count = state.get("retry_count", {})
    if "validate_cards" not in retry_count:
        retry_count["validate_cards"] = {}

    failed_sections = []

    for section in sections:
        if section == "lifestyle":
            subs = get_lifestyle_subsection_keys(survey)
            all_cards = []
            for sub_key in subs:
                all_cards.extend(section_cards.get(f"{section}.{sub_key}", []))
            cards = section_cards.get(section, []) or all_cards[:4]
            if not cards:
                print(f"  ⚠️ [{section}] 카드 수 부족 (0개)")
                failed_sections.append(section)
                continue
        else:
            cards = section_cards.get(section, [])
            if len(cards) != 4:
                print(f"  ⚠️ [{section}] 카드 수 부족 ({len(cards)}개)")
                failed_sections.append(section)
                continue

        result = validate_section_cards(
            section, cards, survey, user_profile, extracted_claims.get(section, {}),
        )
        if not result["passed"]:
            print(f"  ❌ [{section}] 품질 검증 실패: {result['reason']}")
            failed_sections.append(section)
        else:
            print(f"  ✅ [{section}] 품질 검증 통과")

    if failed_sections:
        section_retry = retry_count.get("validate_cards", {})
        retry_to_add = []
        for section in failed_sections:
            count = section_retry.get(section, 0)
            if count <= 1:
                print(f"  🔄 [{section}] 재시도 예정 ({count}회)")
                section_retry[section] = count + 1
                retry_to_add.append(section)
            else:
                print(f"  ⚠️ [{section}] 재시도 횟수 초과 ({count}회)")
        retry_count["validate_cards"] = section_retry
        if retry_to_add:
            state["retry_needed"] = True
            state["retry_sections"] = retry_to_add

    quality_flags = state.get("quality_flags", {})
    quality_flags["validation_passed"] = len(failed_sections) == 0
    return {**state, "retry_count": retry_count, "quality_flags": quality_flags}


# ════════════════════════════════════════════════════════════════
#  노드 7: AssembleReport
# ════════════════════════════════════════════════════════════════

def assemble_report(state: ReportState) -> ReportState:
    """최종 리포트 조립"""
    print("[AssembleReport] 리포트 조립 시작")
    survey = state.get("survey", {})
    sections = state.get("active_sections", [])
    section_cards = state.get("section_cards", {})
    quant_results = state.get("quant_evidence_results", {})
    narrative_evidence = state.get("narrative_evidence", {})

    sections_dict: Dict[str, Any] = {}

    for section in sections:
        cards = section_cards.get(section, [])
        if not cards:
            continue

        narrative_refs = _collect_narrative_refs(narrative_evidence.get(section, {}))
        quant_refs = quant_results.get(section, {}).get("quant_refs", [])

        if section == "lifestyle":
            subsections = []
            sub_titles = {"smoking": "흡연", "drinking": "음주", "stress": "스트레스"}
            for sub_key in get_lifestyle_subsection_keys(survey):
                sub_cards = section_cards.get(f"{section}.{sub_key}", [])
                if sub_cards:
                    subsections.append({
                        "key": sub_key,
                        "title": sub_titles.get(sub_key, sub_key),
                        "cards": sub_cards,
                        "evidence_refs": {"narrative": narrative_refs, "quant": quant_refs},
                    })
            if subsections:
                sections_dict[section] = {
                    "title": SECTION_TITLES.get(section, section),
                    "subsections": subsections,
                    "evidence_refs": {"narrative": narrative_refs, "quant": quant_refs},
                }
                continue

        sections_dict[section] = {
            "title": SECTION_TITLES.get(section, section),
            "cards": cards,
            "evidence_refs": {"narrative": narrative_refs, "quant": quant_refs},
        }

    final_report = {
        "tabs": sections,
        "sections": sections_dict,
        "survey_summary": {
            "outcomes": survey.get("outcomes", []),
            "target_years": survey.get("target_years", 30),
        },
        "generated_at": None,
    }

    print(f"✅ [AssembleReport] 완료 - {len(sections_dict)}개 섹션")
    return {**state, "final_report": final_report}


def _collect_narrative_refs(section_evidence) -> List[Dict[str, Any]]:
    """narrative evidence에서 참조 목록 수집"""
    refs = []
    seen_ids = set()

    items_list = []
    if isinstance(section_evidence, dict):
        for card_type in ["problem", "cause", "action"]:
            items_list.extend(section_evidence.get(card_type, []))
    elif isinstance(section_evidence, list):
        items_list = section_evidence

    for item in items_list:
        if hasattr(item, 'paper_id') and hasattr(item, 'chunk_id'):
            item_id = f"{item.paper_id}_{item.chunk_id}"
            if item_id not in seen_ids:
                seen_ids.add(item_id)
                refs.append({
                    "paper_id": item.paper_id,
                    "chunk_id": item.chunk_id,
                    "title": getattr(item, 'title', None),
                    "pmid": getattr(item, 'pmid', None),
                    "section_norm": getattr(item, 'section_norm', ''),
                    "topics": getattr(item, 'topics', []),
                })
    return refs


# ════════════════════════════════════════════════════════════════
#  노드 8: SaveReport
# ════════════════════════════════════════════════════════════════

def save_report_node(state: ReportState) -> ReportState:
    """리포트 저장"""
    print("[SaveReport] 리포트 저장 시작")
    user_id = state["user_id"]
    final_report = state.get("final_report")
    survey = state.get("survey", {})

    if not final_report:
        print("⚠️ [SaveReport] 저장할 리포트가 없습니다.")
        return state

    try:
        result = save_report(user_id, final_report, lifestyle_id=survey.get("lifestyle_id"))
        if "error" in result:
            print(f"⚠️ [SaveReport] 저장 실패: {result['error']}")
        else:
            print(f"✅ [SaveReport] 저장 완료 - report_id: {result.get('report_id')}")
            final_report["report_id"] = result.get("report_id")
            final_report["generated_at"] = result.get("timestamp")
        return {**state, "final_report": final_report}
    except Exception as e:
        print(f"❌ [SaveReport] 저장 실패: {e}")
        return state


# ════════════════════════════════════════════════════════════════
#  그래프 조립 + 엔트리포인트
# ════════════════════════════════════════════════════════════════

def create_report_graph():
    """리포트 생성 LangGraph 워크플로우 생성"""
    workflow = StateGraph(ReportState)

    workflow.add_node("load_survey", load_survey)
    workflow.add_node("plan_sections", plan_sections)
    workflow.add_node("derive_user_profile", derive_user_profile)
    workflow.add_node("preload_quant_evidence", preload_quant_evidence)
    workflow.add_node("build_queries", build_queries)
    workflow.add_node("retrieve_narrative_evidence", retrieve_narrative_evidence)
    workflow.add_node("extract_claims", extract_claims)
    workflow.add_node("write_section_cards", write_section_cards)
    workflow.add_node("validate_cards", validate_cards)
    workflow.add_node("assemble_report", assemble_report)
    workflow.add_node("save_report", save_report_node)

    workflow.set_entry_point("load_survey")
    workflow.add_edge("load_survey", "plan_sections")
    workflow.add_edge("plan_sections", "derive_user_profile")
    workflow.add_edge("derive_user_profile", "preload_quant_evidence")
    workflow.add_edge("preload_quant_evidence", "build_queries")
    workflow.add_edge("build_queries", "retrieve_narrative_evidence")
    workflow.add_edge("retrieve_narrative_evidence", "extract_claims")
    workflow.add_edge("extract_claims", "write_section_cards")
    workflow.add_edge("write_section_cards", "validate_cards")

    def should_retry(s: ReportState) -> str:
        if s.get("retry_needed", False) and s.get("retry_sections"):
            rc = s.get("retry_count", {}).get("validate_cards", {})
            for sec in s.get("retry_sections", []):
                if rc.get(sec, 0) <= 1:
                    return "retry"
        return "continue"

    workflow.add_conditional_edges(
        "validate_cards", should_retry,
        {"retry": "write_section_cards", "continue": "assemble_report"},
    )
    workflow.add_edge("assemble_report", "save_report")
    workflow.add_edge("save_report", END)

    return workflow.compile(checkpointer=MemorySaver())


def generate_report(user_id: int, lifestyle_id: Optional[int] = None) -> Dict[str, Any]:
    """리포트 생성 메인 함수"""
    try:
        initial_state: ReportState = {
            "user_id": user_id,
            "lifestyle_id": lifestyle_id,
            "survey": None,
            "user_profile": None,
            "active_sections": [],
            "available_quant_outcomes": None,
            "quant_evidence_results": {},
            "section_queries": {},
            "narrative_evidence": {},
            "section_cards": {},
            "quality_flags": {},
            "final_report": None,
        }

        app = create_report_graph()
        config = {"configurable": {"thread_id": f"user_{user_id}"}}

        final_state = None
        for state in app.stream(initial_state, config):
            final_state = state

        if final_state:
            last_key = list(final_state.keys())[-1] if final_state else None
            result_state = final_state[last_key] if last_key else initial_state
            final_report = result_state.get("final_report")
            if final_report:
                return {"success": True, "report": final_report}

        return {"success": False, "error": "리포트 생성 실패"}
    except Exception as e:
        print(f"[오류] 리포트 생성 실패: {str(e)}")
        traceback.print_exc()
        return {"success": False, "error": str(e)}
