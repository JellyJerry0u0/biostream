"""
리포트 카드 생성, 후처리, 검증
- 섹션 카드 생성 (LLM 기반 + 기본 카드 fallback)
- 프롬프트 빌더
- 듀얼 쿼리 (영어 + 한국어)
- 후처리: 문장 제한, PMC 제거, simulation 템플릿 등
- 품질 검증 (validate_cards 노드에서 사용)
"""

import re
from typing import Dict, Any, List, Optional

from .report_constants import (
    ReportState,
    OUTCOME_LABELS,
    SECTION_CARD_TYPE_KEYWORDS,
    CARD_SYSTEM_PROMPT,
    LIFESTYLE_COMBINED_SYSTEM_PROMPT,
)
from .report_llm import invoke_llm_json, REPORT_DEBUG
from .report_formatters import (
    normalize_survey_value,
    format_survey_data,
    get_personalization_note,
    format_quant_data,
    format_user_profile_for_prompt,
    timeframe_days_to_label,
    strip_markdown,
)


# ════════════════════════════════════════════════════════════════
#  프롬프트 빌더
# ════════════════════════════════════════════════════════════════

def build_card_prompt_enhanced(
    section: str, survey: dict, section_quant: dict,
    section_claims: dict, user_profile: dict,
    situation_text: Optional[str] = None,
) -> str:
    """카드 생성 프롬프트 (근거 기반 강화 버전)"""
    survey_text = format_survey_data(section, survey)
    profile_text = format_user_profile_for_prompt(user_profile)
    quant_text = format_quant_data(section_quant)

    claims_texts = _format_claims_text(section_claims)
    claims_text = "\n\n".join(claims_texts) if claims_texts else "구조화된 주장 없음"
    personalization_note = get_personalization_note(section, survey)

    situation_block = ""
    if situation_text and situation_text.strip():
        situation_block = f"""
🔥 [필수] 사용자가 직접 입력한 참고 상황 (action 카드에 반드시 반영):
"{situation_text.strip()[:300]}"
→ action 3개 중 최소 1개는 위 내용(예: 모낭염이면 턱 부위 관리, 피부결이면 각질/수분 조언)을 구체적으로 언급해야 합니다. 무시하면 안 됩니다.

"""
    return f"""섹션: {section}
{situation_block}
⚠️ 중요: 반드시 사용자 설문 데이터와 구조화된 주장(claims)을 바탕으로 개인화된 리포트를 작성하세요.
일반론적 표현("수면이 부족하면", "자외선에 노출되면")은 절대 사용하지 마세요.
"당신의", "당신은" 같은 2인칭을 반드시 사용하세요.
{personalization_note}[사용자 설문 데이터 - 반드시 이 값들을 자연스럽게 요약해 반영하세요]
{survey_text}

[사용자 기본 정보 - 의학적으로 자연스럽게 반영하세요]
{profile_text}
예: "30대 중반 남성에서", "BMI가 높은 편이라", "연령대 특성상..."

[정량 근거]
{quant_text}

[구조화된 주장(claims) - 이 주장들을 바탕으로 카드 텍스트를 작성하세요]
{claims_text}

⚠️ 각 카드 작성 규칙:
- 논리적·유기적 연결: [현재 상태]→[왜 이런 상태인가]→[행동 3가지]가 하나의 흐름. 사용자 설문·참고 상황·논문 근거(claims)를 세 카드 모두에 골고루 반영하고, 각 섹션이 서로를 인용·반영하세요.
- problem/cause: 위 claims의 "claim"과 "support_text"를 바탕으로 작성하되, 설문 수치를 자연스럽게 요약해 반영
- action: 반드시 앞선 [현재 상태]+[왜 이런 상태인가]와 연계. action 3개 각각이 위에서 말한 원인(cause)을 해결하는 구체적 행동이어야 함. 설문+신체정보+참고 상황 고려. 위 [참고 상황]이 있으면 그중 최소 1개는 그 상황에 직접 맞는 조언. 정량적 효과(%, 기간 등)는 action에 넣지 마세요.
- simulation: [정량 근거]에 있는 효과량(%, 기간)을 모두 여기에 반영하세요. 여러 가지가 있으면 모두 나열해도 됩니다.
- 각 카드에 evidence 기반 키워드(근거 support_text에서 추출한 키워드) 최소 1개 포함
- 불확실하면 약하게('가능성이 큽니다/경향이 있습니다') 표현
- 근거에서 말하는 메커니즘/방향성(예: 장벽/염증/멜라닌/콜라겐)을 1번 이상 언급

위 정보를 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.
각 카드는 사용자 설문 데이터와 구조화된 주장을 바탕으로 개인화되게 작성하세요."""


def build_card_prompt(
    section: str, survey: dict, section_quant: dict, narrative_items: list,
    situation_text: Optional[str] = None,
) -> str:
    """카드 생성 프롬프트 (기본 버전)"""
    survey_text = format_survey_data(section, survey)
    quant_text = format_quant_data(section_quant)
    narrative_text = (
        "\n\n".join([item.text[:200] for item in narrative_items[:3]])
        if narrative_items else "관련 근거 없음"
    )
    personalization_note = get_personalization_note(section, survey)

    situation_block = ""
    if situation_text and situation_text.strip():
        situation_block = f"""
🔥 [필수] 사용자가 직접 입력한 참고 상황 (action 카드에 반드시 반영):
"{situation_text.strip()[:300]}"
→ action 3개 중 최소 1개는 위 내용(예: 모낭염이면 턱 부위 관리, 피부결이면 각질/수분 조언)을 구체적으로 언급해야 합니다. 무시하면 안 됩니다.

"""
    return f"""섹션: {section}
{situation_block}
⚠️ 중요: 반드시 사용자 설문 데이터를 직접 인용하여 개인화된 리포트를 작성하세요.
일반론적 표현("수면이 부족하면", "자외선에 노출되면")은 절대 사용하지 마세요.
"당신의", "당신은" 같은 2인칭을 반드시 사용하세요.
{personalization_note}[사용자 설문 데이터 - 반드시 이 값들을 직접 인용하세요]
{survey_text}

[정량 근거]
{quant_text}

[원문 근거 (참고용)]
{narrative_text}

⚠️ [현재 상태]→[왜 이런 상태인가]→[행동 3가지]가 하나의 흐름. 사용자 설문·참고 상황·근거를 세 카드 모두에 골고루 반영하고, 각 섹션이 서로를 인용·반영하세요.

위 정보를 바탕으로 4개의 카드를 JSON 형식으로 생성하세요.
각 카드는 사용자 설문 데이터를 직접 인용하여 개인화되게 작성하세요."""


def _format_claims_text(section_claims: dict) -> List[str]:
    """claims를 프롬프트용 텍스트로 포맷"""
    claims_texts = []
    for card_type in ["problem", "cause", "action"]:
        claims = section_claims.get(card_type, [])
        if not claims:
            continue
        card_claims = []
        for claim_data in claims[:2]:
            claim_str = claim_data.get("claim", "")
            support_list = claim_data.get("support", [])
            support_texts = [s.get("support_text", "") for s in support_list[:1]]
            card_claims.append(f"- {claim_str}\n  근거: {'; '.join(support_texts)}")
        if card_claims:
            claims_texts.append(f"[{card_type} 카드용 주장]\n" + "\n".join(card_claims))
    return claims_texts


# ════════════════════════════════════════════════════════════════
#  듀얼 쿼리 (영어 + 한국어)
# ════════════════════════════════════════════════════════════════

_SECTION_ENGLISH_KEYWORDS = {
    "sleep": ["sleep duration", "sleep deprivation", "skin barrier", "hydration", "inflammation", "cortisol"],
    "uv": ["UV exposure", "photoaging", "sunscreen", "SPF", "wrinkles", "pigmentation", "oxidative stress"],
    "lifestyle": ["psychological stress", "cortisol", "inflammation", "acne", "skin barrier"],
    "activity": ["exercise", "physical activity", "skin elasticity", "collagen", "metabolism"],
}

_OUTCOME_ENGLISH_MAP = {
    "wrinkle": ["wrinkle", "skin elasticity", "collagen", "clinical trial"],
    "elasticity": ["skin elasticity", "collagen", "wrinkle", "clinical trial"],
    "hydration": ["skin barrier", "hydration", "moisture", "clinical trial"],
    "hydration_barrier": ["skin barrier", "hydration", "moisture", "clinical trial"],
    "pigmentation": ["pigmentation", "melanin", "hyperpigmentation", "clinical trial"],
    "acne": ["acne", "inflammation", "sebum", "clinical trial"],
    "redness": ["erythema", "redness", "inflammation", "clinical trial"],
}


def build_dual_queries(
    section: str, card_type: str, survey: dict,
    user_profile: dict, outcome_keywords: Optional[List[str]] = None,
) -> List[str]:
    """듀얼 쿼리 생성: 영어 쿼리(필수) + 한국어 보조 쿼리(선택)"""
    outcome_keywords = outcome_keywords or []

    if section == "goals":
        outcomes = survey.get("outcomes", [])
        english_keywords = []
        for outcome in outcomes:
            english_keywords.extend(_OUTCOME_ENGLISH_MAP.get(outcome, [outcome]))
        english_keywords = list(set(english_keywords))[:6]
    else:
        english_keywords = _SECTION_ENGLISH_KEYWORDS.get(section, [])

    # card_type × section 조합별 영어 쿼리
    _QUERY_MAP = {
        "problem": {
            "sleep": "sleep deprivation skin barrier hydration inflammation",
            "uv": "UV exposure photoaging sunscreen wrinkles pigmentation",
            "lifestyle": "smoking alcohol stress skin inflammation",
            "activity": "exercise physical activity skin elasticity collagen",
        },
        "cause": {
            "sleep": "sleep fragmentation cortisol inflammation skin barrier mechanism",
            "uv": "UV radiation melanin collagen degradation oxidative stress mechanism",
            "lifestyle": "alcohol nicotine cortisol inflammation skin mechanism",
            "activity": "metabolism collagen synthesis skin health mechanism",
        },
        "action": {
            "sleep": "sleep intervention clinical trial skin barrier improvement",
            "uv": "sunscreen intervention UV protection clinical trial",
            "lifestyle": "lifestyle intervention stress management skin health",
            "activity": "exercise intervention skin health clinical trial",
        },
    }

    suffix_map = {"problem": " skin condition", "cause": " mechanism cause", "action": " intervention treatment"}

    if section in _QUERY_MAP.get(card_type, {}):
        english_query = _QUERY_MAP[card_type][section]
    elif section == "goals":
        suffix = suffix_map.get(card_type, "")
        english_query = " ".join(english_keywords[:4]) + suffix
    else:
        suffix = suffix_map.get(card_type, "")
        english_query = " ".join(english_keywords[:4]) + suffix

    return [english_query]


# ════════════════════════════════════════════════════════════════
#  키워드 기반 문장 추출
# ════════════════════════════════════════════════════════════════

def extract_keyword_based_sentences(text: str, keywords: List[str], max_sentences: int = 2) -> List[str]:
    """키워드 기반으로 문장 추출 (키워드가 포함된 문장 우선)"""
    sentences = re.split(r'[.!?]\s+', text)
    sentences = [s.strip() for s in sentences if s.strip()]
    if not sentences:
        return []

    scored = [(s, sum(1 for kw in keywords if kw.lower() in s.lower())) for s in sentences]
    scored.sort(key=lambda x: x[1], reverse=True)

    selected = [s for s, score in scored[:max_sentences] if len(s) > 30]
    if not selected and sentences:
        selected = [sentences[0][:200]]
    return selected


# ════════════════════════════════════════════════════════════════
#  카드 생성 (LLM 기반 + fallback)
# ════════════════════════════════════════════════════════════════

def generate_section_cards(
    section: str, survey: dict, quant_results: dict,
    extracted_claims: dict, user_profile: dict, state: ReportState,
) -> List[Dict[str, Any]]:
    """일반 섹션의 카드 생성"""
    section_quant = quant_results.get(section, {})
    section_claims = extracted_claims.get(section, {}) if extracted_claims else {}

    # evidence_map: postprocess에서 meta.evidence_chunk_ids를 채우기 위한 데이터
    evidence_map = {
        "narrative_evidence": state.get("narrative_evidence", {}).get(section, {}),
        "extracted_claims": section_claims,
    }

    has_claims = (
        any(section_claims.get(ct) for ct in ["problem", "cause", "action"])
        if section_claims else False
    )
    print(f"  [{section}] has_claims={has_claims}")

    situation_text = state.get("situation_text") or ""
    if situation_text:
        print(f"  [{section}] situation_text 프롬프트에 반영: {situation_text[:50]}...")

    if has_claims:
        try:
            prompt = build_card_prompt_enhanced(
                section, survey, section_quant, section_claims, user_profile,
                situation_text=situation_text,
            )
            if REPORT_DEBUG:
                print(f"    📝 [{section}] enhanced 프롬프트 길이: {len(prompt)}자")
        except Exception as e:
            print(f"    ⚠️ [{section}] enhanced 프롬프트 생성 실패, 기본 프롬프트 사용: {e}")
            has_claims = False

    if not has_claims:
        print(f"    ⚠️ [{section}] claims가 없어 기본 프롬프트 사용")
        narrative_items_flat = []
        section_evidence = state.get("narrative_evidence", {}).get(section, {})
        if isinstance(section_evidence, dict):
            for card_type in ["problem", "cause", "action"]:
                items = section_evidence.get(card_type, [])
                narrative_items_flat.extend(items[:2])
        elif isinstance(section_evidence, list):
            narrative_items_flat = section_evidence[:5]
        prompt = build_card_prompt(
            section, survey, section_quant, narrative_items_flat,
            situation_text=situation_text,
        )

    try:
        context = f"write_section_cards.{section}"
        cards_json = invoke_llm_json(prompt, CARD_SYSTEM_PROMPT, retry=True, context=context)

        if cards_json is None:
            print(f"    ❌ [{section}] LLM 호출 실패, 기본 카드 생성")
            return _postprocess_default_cards(section, survey, section_quant, user_profile, evidence_map=evidence_map)
        elif "cards" not in cards_json or not cards_json.get("cards"):
            print(f"    ❌ [{section}] JSON에 cards 키 없음, 기본 카드 생성")
            return _postprocess_default_cards(section, survey, section_quant, user_profile, evidence_map=evidence_map)
        else:
            raw_cards = cards_json["cards"]
            processed_cards, quality_flags = postprocess_cards(raw_cards, section_quant, section, survey, user_profile, evidence_map=evidence_map)
            if quality_flags.get("leaked_citation"):
                print(f"    ⚠️ PMC/논문ID 노출 발견 및 제거됨")
            print(f"    ✅ [{section}] {len(processed_cards)}개 카드 생성 완료")
            return processed_cards
    except Exception as e:
        import traceback
        print(f"    ❌ [{section}] 카드 생성 예외: {e}")
        if REPORT_DEBUG:
            print(f"    📝 에러 상세:\n{traceback.format_exc()}")
        return _postprocess_default_cards(section, survey, section_quant, user_profile, evidence_map=evidence_map)


def _postprocess_default_cards(
    section: str, survey: dict, section_quant: dict, user_profile: dict,
    evidence_map: Optional[Dict] = None,
) -> List[Dict[str, Any]]:
    """기본 카드 → 후처리까지 한 번에"""
    default_cards = create_default_cards(section, survey)
    processed, _ = postprocess_cards(default_cards, section_quant, section, survey, user_profile, evidence_map=evidence_map)
    return processed


# ════════════════════════════════════════════════════════════════
#  생활습관 통합 카드 생성 (1회 LLM → smoking/drinking/stress)
# ════════════════════════════════════════════════════════════════

_SUBSECTION_LABELS = {
    "smoking": "흡연",
    "drinking": "음주",
    "stress": "스트레스",
}

_SUBSECTION_SKIN_FOCUS = {
    "smoking": "흡연이 피부 콜라겐 분해, 혈류 저하, 산화 스트레스에 미치는 영향에 집중",
    "drinking": "음주가 피부 탈수, 염증, 장벽 회복 방해에 미치는 영향에 집중",
    "stress": "만성 스트레스가 코르티솔 분비, 세라마이드 합성 억제, 피부 장벽 약화에 미치는 영향에 집중",
}


def build_lifestyle_combined_prompt(
    subsection_keys: List[str],
    survey: dict,
    section_quant: dict,
    section_claims: dict,
    user_profile: dict,
    situation_text: Optional[str] = None,
) -> str:
    """생활습관 서브섹션 통합 프롬프트 (1회 호출용)"""
    profile_text = format_user_profile_for_prompt(user_profile)
    quant_text = format_quant_data(section_quant)

    situation_block = ""
    if situation_text and situation_text.strip():
        situation_block = f"""
🔥 [필수] 사용자가 직접 입력한 참고 상황 (action 카드에 반드시 반영):
"{situation_text.strip()[:300]}"
→ action 3개 중 최소 1개는 위 내용(예: 모낭염이면 턱 부위 관리, 피부결이면 각질/수분 조언)을 구체적으로 언급해야 합니다. 무시하면 안 됩니다.

"""
    # 서브섹션별 설문 데이터 정리
    survey_parts = []
    smoking_kr = normalize_survey_value(survey.get("smoking_status", "N/A"), "smoking_status")
    drinking = survey.get("drinking_days_per_week", "N/A")
    stress = survey.get("stress_score", "N/A")

    if "smoking" in subsection_keys:
        survey_parts.append(f"[흡연]\n- 흡연 상태: {smoking_kr}")
    if "drinking" in subsection_keys:
        survey_parts.append(f"[음주]\n- 주당 음주 일수: {drinking}일")
    if "stress" in subsection_keys:
        survey_parts.append(f"[스트레스]\n- 스트레스 점수: {stress}/10점")

    survey_text = "\n\n".join(survey_parts)

    # claims 포맷
    claims_texts = _format_claims_text(section_claims) if section_claims else []
    claims_text = "\n\n".join(claims_texts) if claims_texts else "구조화된 주장 없음"

    # 서브섹션별 요구사항
    sub_requirements = []
    for key in subsection_keys:
        label = _SUBSECTION_LABELS.get(key, key)
        focus = _SUBSECTION_SKIN_FOCUS.get(key, "피부 건강에 미치는 영향에 집중")
        sub_requirements.append(
            f"- \"{key}\" 서브섹션: {label} → {focus}"
        )
    sub_requirements_text = "\n".join(sub_requirements)

    subsection_keys_str = ", ".join([f'"{k}"' for k in subsection_keys])

    return f"""섹션: lifestyle (생활습관)
서브섹션: {subsection_keys_str}
{situation_block}
⚠️ 중요: 각 서브섹션({', '.join([_SUBSECTION_LABELS.get(k, k) for k in subsection_keys])})별로 독립적인 4개 카드를 생성하세요.
각 서브섹션의 카드는 해당 생활습관 요인에만 집중하세요. 다른 요인을 혼합하지 마세요.
"당신의", "당신은" 같은 2인칭을 반드시 사용하세요.

{sub_requirements_text}

[사용자 설문 데이터 - 반드시 해당 서브섹션의 수치를 자연스럽게 반영하세요]
{survey_text}

[사용자 기본 정보]
{profile_text}

[정량 근거]
{quant_text}

[구조화된 주장(claims)]
{claims_text}

⚠️ 각 카드 작성 규칙:
- 논리적·유기적 연결: [현재 상태]→[왜 이런 상태인가]→[행동 3가지]가 하나의 흐름. 사용자 설문·참고 상황·논문 근거를 세 카드 모두에 골고루 반영하고, 각 섹션이 서로를 인용·반영하세요.
- problem: 이 사용자의 현재 해당 습관이 피부에 미치는 상태를 구체적으로 서술
- cause: 해당 습관이 피부에 악영향을 미치는 생물학적 메커니즘 설명
- action: 반드시 앞선 [현재 상태]+[왜 이런 상태인가]와 연계. action 3개 각각이 위에서 말한 원인(cause)을 해결하는 구체적 행동이어야 함. 위 [참고 상황]이 있으면 그중 최소 1개는 그 상황에 직접 맞는 조언. 정량적 효과는 action에 넣지 마세요.
- simulation: 12주 후 개선 예상 경로. [정량 근거]의 효과량(%, 기간)을 모두 여기에 반영. 여러 가지가 있으면 모두 나열
- 불확실하면 약하게('가능성이 큽니다/경향이 있습니다') 표현
- 근거에서 말하는 메커니즘/방향성을 1번 이상 언급

위 정보를 바탕으로 {len(subsection_keys)}개 서브섹션의 카드를 JSON 형식으로 생성하세요."""


def generate_lifestyle_cards(
    survey: dict,
    quant_results: dict,
    extracted_claims: dict,
    user_profile: dict,
    state: ReportState,
) -> Dict[str, List[Dict[str, Any]]]:
    """
    생활습관 서브섹션 카드를 1회 LLM 호출로 통합 생성.

    Returns:
        {"smoking": [4 cards], "drinking": [4 cards], "stress": [4 cards]}
        (활성화된 서브섹션만 포함)
    """
    subsection_keys = get_lifestyle_subsection_keys(survey)
    if not subsection_keys:
        return {}

    section_quant = quant_results.get("lifestyle", {})
    section_claims = extracted_claims.get("lifestyle", {}) if extracted_claims else {}

    evidence_map = {
        "narrative_evidence": state.get("narrative_evidence", {}).get("lifestyle", {}),
        "extracted_claims": section_claims,
    }

    # ── 프롬프트 빌드 & LLM 호출 ──
    situation_text = state.get("situation_text") or ""
    if situation_text:
        print(f"  [lifestyle] situation_text 프롬프트에 반영: {situation_text[:50]}...")
    prompt = build_lifestyle_combined_prompt(
        subsection_keys, survey, section_quant, section_claims, user_profile,
        situation_text=situation_text,
    )
    if REPORT_DEBUG:
        print(f"    📝 [lifestyle] combined 프롬프트 길이: {len(prompt)}자, 서브섹션: {subsection_keys}")

    result: Dict[str, List[Dict[str, Any]]] = {}

    try:
        cards_json = invoke_llm_json(
            prompt, LIFESTYLE_COMBINED_SYSTEM_PROMPT, retry=True,
            context="write_section_cards.lifestyle_combined",
        )

        if cards_json and "subsections" in cards_json:
            subsections_data = cards_json["subsections"]
            for sub_key in subsection_keys:
                sub_data = subsections_data.get(sub_key)
                if sub_data and "cards" in sub_data and len(sub_data["cards"]) >= 3:
                    raw_cards = sub_data["cards"]
                    composite_key = f"lifestyle.{sub_key}"
                    processed, quality_flags = postprocess_cards(
                        raw_cards, section_quant, composite_key,
                        survey, user_profile, evidence_map=evidence_map,
                    )
                    if quality_flags.get("leaked_citation"):
                        print(f"    ⚠️ [lifestyle.{sub_key}] PMC 노출 제거됨")
                    result[sub_key] = processed
                    print(f"    ✅ [lifestyle.{sub_key}] LLM 카드 {len(processed)}개 생성")
                else:
                    print(f"    ⚠️ [lifestyle.{sub_key}] LLM 응답에 유효 카드 없음 → 템플릿 fallback")
        else:
            print(f"    ⚠️ [lifestyle] LLM 응답에 subsections 키 없음")

    except Exception as e:
        import traceback
        print(f"    ❌ [lifestyle] LLM 통합 호출 실패: {e}")
        if REPORT_DEBUG:
            print(f"    📝 에러 상세:\n{traceback.format_exc()}")

    # ── 누락된 서브섹션은 템플릿 fallback ──
    for sub_key in subsection_keys:
        if sub_key not in result:
            print(f"    🔄 [lifestyle.{sub_key}] 템플릿 fallback 사용")
            result[sub_key] = create_template_based_subsection_cards(
                "lifestyle", sub_key, survey, quant_results, user_profile,
                evidence_map=evidence_map,
            )

    return result


# ════════════════════════════════════════════════════════════════
#  기본 카드 / 템플릿 카드 생성
# ════════════════════════════════════════════════════════════════

def get_lifestyle_subsection_keys(survey: dict) -> List[str]:
    """생활습관 섹션의 하위 섹션 키 목록"""
    subsections = []
    smoking = survey.get("smoking_status")
    if smoking and str(smoking).lower() not in ["never", "안", "비흡연", "never smoked", "none", ""]:
        subsections.append("smoking")
    drinking = survey.get("drinking_days_per_week")
    # drinking_days_per_week는 문자열 ('0', '1', '2-3', '4-5', '6-7')
    if drinking is not None and str(drinking) not in ["0", "", "none"]:
        subsections.append("drinking")
    stress = survey.get("stress_score")
    if stress is not None and float(stress) > 0:
        subsections.append("stress")
    return subsections


def create_template_based_subsection_cards(
    section: str, subsection_key: str, survey: dict,
    quant_results: dict, user_profile: dict,
    evidence_map: Optional[Dict] = None,
) -> List[Dict[str, Any]]:
    """하위 섹션별 템플릿 기반 카드 (LLM 호출 없음)"""
    section_quant = quant_results.get(section, {})
    cards = _create_default_subsection_cards(section, subsection_key, survey)
    # section_key를 "lifestyle.smoking" 형태로 전달 → build_section_condition에서 서브섹션별 조건 생성
    composite_key = f"{section}.{subsection_key}"
    processed, _ = postprocess_cards(cards, section_quant, composite_key, survey, user_profile, evidence_map=evidence_map)
    return processed


def _create_default_subsection_cards(section: str, subsection_key: str, survey: dict) -> List[Dict[str, Any]]:
    """하위 섹션별 기본 카드"""
    templates = {
        "smoking": lambda: _smoking_cards(survey),
        "drinking": lambda: _drinking_cards(survey),
        "stress": lambda: _stress_cards(survey),
    }
    builder = templates.get(subsection_key)
    if builder:
        problem_text, cause_text, action_items = builder()
    else:
        problem_text = "현재 확보된 근거 범위 내에서 분석 중입니다."
        cause_text = "근거가 부족해 보수적으로 제안합니다."
        action_items = [
            {"title": "행동 1", "detail": "근거 확보 후 제안하겠습니다."},
            {"title": "행동 2", "detail": "근거 확보 후 제안하겠습니다."},
            {"title": "행동 3", "detail": "근거 확보 후 제안하겠습니다."},
        ]

    _sub_sim_map = {
        "smoking": "흡연 관리를 통해 피부 노화 속도가 점진적으로 개선될 것으로 기대됩니다.",
        "drinking": "음주량 관리를 통해 피부 염증 수준이 점진적으로 개선될 것으로 기대됩니다.",
        "stress": "스트레스 관리를 통해 피부 스트레스 반응이 점진적으로 개선될 것으로 기대됩니다.",
    }
    sim_text = _sub_sim_map.get(subsection_key, "생활습관 개선을 통해 피부 상태가 점진적으로 개선될 것으로 기대됩니다.")

    return [
        {"type": "problem", "title": "현재 상태", "text": problem_text},
        {"type": "cause", "title": "왜 이런 상태인가", "text": cause_text},
        {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": action_items},
        {
            "type": "simulation", "title": "12주 후 예상 경로",
            "text": sim_text,
            "meta": {
                "mode": "estimated",
                "disclaimer_small": "정량 근거가 부족해 논문 전반을 바탕으로 AI가 보수적으로 추정한 값입니다. 개인차가 큽니다.",
            },
        },
    ]


def _smoking_cards(survey: dict):
    smoking = survey.get("smoking_status", "N/A")
    smoking_kr = normalize_survey_value(smoking, "smoking_status") if smoking else "흡연 여부 미확인"
    return (
        f"현재 흡연 상태가 '{smoking_kr}'인 편입니다. 흡연은 피부 콜라겐 분해를 촉진하고 혈류 순환을 저하시켜 피부 노화를 가속화합니다.",
        "담배 연기 속 활성산소가 피부 세포를 직접 손상시키고, 니코틴이 혈관을 수축시켜 영양소와 산소 공급이 줄어들기 때문입니다.",
        [
            {"title": "흡연량 줄이기", "detail": "하루 흡연량을 절반으로 줄여, 피부에 가해지는 산화 스트레스를 낮추세요."},
            {"title": "금연 계획 세우기", "detail": "단계적으로 금연을 시작하면 2~4주 내 혈류 개선 효과를 체감할 수 있습니다."},
            {"title": "항산화 케어 강화", "detail": "비타민 C 세럼 등 항산화 제품을 사용해 활성산소로 인한 피부 손상을 완화하세요."},
        ],
    )


def _drinking_cards(survey: dict):
    drinking = survey.get("drinking_days_per_week", 0)
    return (
        f"주당 음주 빈도가 {drinking}일인 편입니다. 잦은 음주는 피부 탈수와 염증 반응을 유발해 피부 장벽 회복을 방해합니다.",
        "알코올이 체내 수분을 빼앗고 간 기능에 부담을 주면서, 피부에 필요한 비타민과 항산화 물질의 흡수가 저하되기 때문입니다.",
        [
            {"title": "음주 빈도 줄이기", "detail": "주당 음주 일수를 1~2일로 줄여 피부 회복 시간을 확보하세요."},
            {"title": "음주량 조절하기", "detail": "한 번에 마시는 양을 소주 2잔 이하로 줄이면 다음 날 피부 붓기가 줄어듭니다."},
            {"title": "음주 후 수분 보충", "detail": "음주 후 물을 충분히 마시고, 보습제를 바로 발라 탈수를 완화하세요."},
        ],
    )


def _stress_cards(survey: dict):
    stress = survey.get("stress_score", 0)
    level = "높은" if stress and float(stress) >= 7 else "보통 이상인"
    return (
        f"스트레스 수준이 {stress}/10점으로 {level} 편입니다. 만성 스트레스는 코르티솔 분비를 높여 피부 장벽을 약화시키고, 염증 반응을 촉진합니다.",
        "코르티솔이 지속적으로 분비되면 피부 세라마이드 합성이 억제되고, 피지 분비가 증가하면서 여드름·건조함이 동시에 나타날 수 있습니다.",
        [
            {"title": "스트레스 관리 루틴 만들기", "detail": "하루 10분 명상이나 가벼운 스트레칭만으로도 코르티솔 수치를 낮출 수 있습니다."},
            {"title": "충분한 휴식 시간 확보", "detail": "의도적으로 디지털 기기를 내려놓는 시간을 만들어 뇌 피로를 줄이세요."},
            {"title": "수면의 질 개선", "detail": "자기 전 1시간은 블루라이트를 차단하고, 규칙적인 수면 패턴을 유지하세요."},
        ],
    )


def create_default_cards(section: str, survey: dict = None) -> List[Dict[str, Any]]:
    """기본 카드 생성 (fallback)"""
    survey = survey or {}
    problem_text = "현재 생활습관이 피부에 미치는 영향을 분석하고 있습니다."
    cause_text = "생활습관과 환경 요인이 복합적으로 피부 건강에 영향을 줍니다."
    action_items = [
        {"title": "피부 보습 강화", "detail": "세안 후 3분 이내에 보습제를 발라 수분 증발을 막으세요."},
        {"title": "자외선 차단 습관", "detail": "외출 시 SPF 30 이상 선크림을 사용하세요."},
        {"title": "충분한 수분 섭취", "detail": "하루 1.5~2L의 물을 나눠 마시세요."},
    ]

    # 설문 기반 개인화 시도
    if section == "sleep":
        hours = survey.get("sleep_hours_weekday")
        if hours is not None:
            try:
                hours_float = float(hours)
                if hours_float < 7:
                    problem_text = f"수면 패턴을 보면 평일 평균 {hours_float:.1f}시간 정도로 부족한 편입니다. 수면 부족은 피부 재생에 필요한 성장호르몬 분비를 저하시킵니다."
                    cause_text = "수면 중 분비되는 멜라토닌과 성장호르몬이 부족해지면서 피부 세포 회복 속도가 느려지기 때문입니다."
                    action_items = [
                        {"title": "수면 시간을 7시간 이상으로 늘리기", "detail": "평일 취침 시간을 30분씩 앞당겨 점진적으로 수면 시간을 확보하세요."},
                        {"title": "수면 전 카페인 섭취 줄이기", "detail": "오후 2시 이후 카페인을 피하면 숙면의 질이 크게 개선됩니다."},
                        {"title": "수면 환경 개선", "detail": "어둡고 서늘한 환경(18~20°C)을 유지하면 멜라토닌 분비에 도움이 됩니다."},
                    ]
            except (ValueError, TypeError):
                pass
    elif section == "uv":
        sunscreen = survey.get("sunscreen_frequency", "")
        sunscreen_kr = normalize_survey_value(sunscreen, "sunscreen_frequency") if sunscreen else "정보 없음"
        if sunscreen:
            problem_text = f"선크림 사용 빈도가 '{sunscreen_kr}'인 편입니다. 자외선은 피부 노화의 가장 큰 외부 요인입니다."
            cause_text = "UV-A는 진피층까지 침투해 콜라겐을 분해하고, UV-B는 표피를 손상시켜 색소침착과 주름을 유발합니다."
            action_items = [
                {"title": "매일 선크림 사용하기", "detail": "흐린 날에도 UV-A가 도달하므로 매일 SPF 30 이상 선크림을 바르세요."},
                {"title": "자외선 강한 시간대 주의", "detail": "오전 10시~오후 4시 사이 야외 활동 시 모자와 선글라스를 활용하세요."},
                {"title": "선크림 재도포하기", "detail": "야외 활동 시 2~3시간마다 선크림을 다시 발라야 효과가 유지됩니다."},
            ]
        else:
            problem_text = "자외선 관리 습관을 확인할 수 없었습니다. 자외선은 피부 노화의 가장 큰 외부 요인입니다."
            cause_text = "UV-A는 진피층까지 침투해 콜라겐을 분해하고, UV-B는 표피를 손상시켜 색소침착과 주름을 유발합니다."
            action_items = [
                {"title": "매일 선크림 사용하기", "detail": "외출 전 SPF 30 이상 선크림을 바르는 습관을 만드세요."},
                {"title": "자외선 강한 시간대 주의", "detail": "오전 10시~오후 4시 사이 야외 활동 시 자외선 차단에 신경 쓰세요."},
                {"title": "자외선 차단 도구 활용", "detail": "모자, 선글라스, 긴 소매 등을 활용해 피부를 보호하세요."},
            ]
    elif section == "lifestyle":
        stress = survey.get("stress_score")
        smoking = survey.get("smoking_status", "")
        smoking_kr = normalize_survey_value(smoking, "smoking_status") if smoking else "정보 없음"
        if stress is not None:
            try:
                if float(stress) >= 7:
                    problem_text = f"스트레스 수준이 {stress}/10점으로 높은 편입니다. 만성 스트레스는 코르티솔 분비를 높여 피부 장벽을 약화시킵니다."
                    cause_text = "코르티솔이 지속적으로 분비되면 피부 세라마이드 합성이 억제되면서 건조함과 염증이 동시에 나타날 수 있습니다."
                    action_items = [
                        {"title": "스트레스 관리 루틴 만들기", "detail": "하루 10분 명상이나 가벼운 스트레칭으로 코르티솔 수치를 낮추세요."},
                        {"title": "충분한 휴식 시간 확보", "detail": "의도적으로 디지털 기기를 내려놓는 시간을 만들어 뇌 피로를 줄이세요."},
                        {"title": "수면의 질 개선", "detail": "자기 전 1시간은 블루라이트를 차단하고 규칙적인 수면 패턴을 유지하세요."},
                    ]
            except (ValueError, TypeError):
                pass
        elif smoking and ("현재" in str(smoking) or "current" in str(smoking).lower()):
            problem_text = f"현재 흡연 상태가 '{smoking_kr}'인 편입니다. 흡연은 피부 콜라겐 분해를 촉진하고 혈류 순환을 저하시킵니다."
            cause_text = "담배 연기 속 활성산소가 피부 세포를 손상시키고, 니코틴이 혈관을 수축시켜 영양소와 산소 공급이 줄어들기 때문입니다."
            action_items = [
                {"title": "흡연량 줄이기", "detail": "하루 흡연량을 절반으로 줄여 피부에 가해지는 산화 스트레스를 낮추세요."},
                {"title": "금연 계획 세우기", "detail": "단계적 금연을 시작하면 2~4주 내 혈류 개선 효과를 체감할 수 있습니다."},
                {"title": "항산화 케어 강화", "detail": "비타민 C 세럼 등 항산화 제품을 사용해 활성산소로 인한 피부 손상을 완화하세요."},
            ]
    elif section == "activity":
        aerobic = survey.get("aerobic_weekly")
        if aerobic is not None:
            try:
                aerobic_int = int(aerobic) if isinstance(aerobic, (int, str)) and str(aerobic).isdigit() else 0
                if aerobic_int < 2:
                    problem_text = "운동 빈도가 낮은 편입니다. 규칙적인 운동은 피부 혈류를 증가시켜 영양소 공급과 노폐물 배출을 돕습니다."
                    cause_text = "운동 부족으로 인한 혈류 저하와 대사 감소가 피부 세포 재생 속도를 늦추기 때문입니다."
                    action_items = [
                        {"title": "주 3회 이상 유산소 운동", "detail": "30분 걷기나 조깅만으로도 피부 혈류가 크게 개선됩니다."},
                        {"title": "근력 운동 추가하기", "detail": "주 2회 이상 근력 운동을 하면 성장호르몬 분비가 촉진됩니다."},
                        {"title": "일상 활동량 늘리기", "detail": "계단 이용, 짧은 산책 등으로 하루 활동량을 조금씩 늘리세요."},
                    ]
            except (ValueError, TypeError):
                pass
    elif section == "goals":
        outcomes = survey.get("outcomes", [])
        outcome_labels = [OUTCOME_LABELS.get(o, o) for o in outcomes[:2]]
        focus_text = ", ".join(outcome_labels) if outcome_labels else "전반적 피부 건강"
        problem_text = f"현재 {focus_text}에 관심을 가지고 계십니다. 생활습관과 환경 요인이 복합적으로 피부 건강에 영향을 미칩니다."
        cause_text = "피부 노화는 자외선·스트레스 같은 외부 요인과 수면·영양 등 내부 요인이 함께 작용한 결과입니다."
        action_items = [
            {"title": "자외선 차단 생활화", "detail": "매일 SPF 30 이상 선크림을 바르고, 외출 시 자외선 차단 도구를 활용하세요."},
            {"title": "보습과 영양 케어", "detail": "세안 후 보습제를 바로 바르고, 비타민 C·E 등 항산화 성분을 활용하세요."},
            {"title": "수면과 스트레스 관리", "detail": "7시간 이상 숙면을 취하고, 스트레스를 줄이는 루틴을 만드세요."},
        ]

    _section_sim_map = {
        "sleep": "수면 습관 개선을 통해 피부 수분 장벽이 점진적으로 개선될 것으로 기대됩니다.",
        "uv": "자외선 관리 강화를 통해 색소침착 방어력이 점진적으로 개선될 것으로 기대됩니다.",
        "lifestyle": "생활습관 개선을 통해 피부 상태가 점진적으로 개선될 것으로 기대됩니다.",
        "activity": "운동 습관 강화를 통해 피부 탄력이 점진적으로 개선될 것으로 기대됩니다.",
        "goals": "맞춤형 관리를 통해 전반적 피부 상태가 점진적으로 개선될 것으로 기대됩니다.",
    }
    sim_text = _section_sim_map.get(section, "관리를 통해 피부 상태가 점진적으로 개선될 것으로 기대됩니다.")

    return [
        {"type": "problem", "title": "현재 상태", "text": problem_text},
        {"type": "cause", "title": "왜 이런 상태인가", "text": cause_text},
        {"type": "action", "title": "당신에게 필요한 행동 3가지", "items": action_items},
        {
            "type": "simulation", "title": "12주 후 예상 경로",
            "text": sim_text,
            "meta": {
                "mode": "estimated",
                "disclaimer_small": "정량 근거가 부족해 논문 전반을 바탕으로 AI가 보수적으로 추정한 값입니다. 개인차가 큽니다.",
            },
        },
    ]


# ════════════════════════════════════════════════════════════════
#  후처리 유틸리티
# ════════════════════════════════════════════════════════════════

def limit_sentences(text: str, max_sentences: int) -> str:
    """문장 수 제한 (숫자 내 . 은 문장 끝으로 보지 않음, 예: 5.2%, 2.0~8.0)"""
    if not text:
        return text

    # (?<![0-9]) ... (?![0-9]): 숫자 사이의 . 은 제외 (5.2, 2.0 등)
    sentences = re.split(r'((?<![0-9])[.!?。！？](?![0-9])\s*)', text)
    result_sentences = []
    for i in range(0, len(sentences) - 1, 2):
        if i + 1 < len(sentences):
            result_sentences.append(sentences[i] + sentences[i + 1])
        else:
            result_sentences.append(sentences[i])

    _sentence_end = r'(?<![0-9])[.!?。！？](?![0-9])'
    if len(result_sentences) == 0 or (len(result_sentences) == 1 and not re.search(_sentence_end, text)):
        return text[:200].strip() + "..." if len(text) > 200 else text

    if len(result_sentences) <= max_sentences:
        return text

    return "".join(result_sentences[:max_sentences]).strip()


def remove_citation_leaks(text: str) -> tuple[str, bool]:
    """PMC/논문ID 본문 노출 제거"""
    if not text:
        return text, False

    leaked = False
    patterns = [
        (r'PMC\d+', ''),
        (r'PMID\s*:?\s*\d+', ''),
        (r'p\s*[=<>]\s*[\d.]+', ''),
        (r'CI\s*:?\s*\[[^\]]+\]', ''),
        (r'confidence interval', ''),
    ]

    cleaned = text
    for pattern, replacement in patterns:
        if re.search(pattern, cleaned, re.IGNORECASE):
            leaked = True
            cleaned = re.sub(pattern, replacement, cleaned, flags=re.IGNORECASE)

    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    return cleaned, leaked


def soften_overconfident_language(text: str) -> str:
    """과확신 표현 완화"""
    if not text:
        return text

    replacements = {
        r'\b반드시\b': '권장됩니다',
        r'\b확실히\b': '가능성이 큽니다',
        r'\b절대적으로\b': '대체로',
        r'\b필수적으로\b': '권장됩니다',
        r'\b100%\b': '높은 확률로',
    }
    result = text
    for pattern, replacement in replacements.items():
        result = re.sub(pattern, replacement, result)
    return result


# ════════════════════════════════════════════════════════════════
#  simulation 카드 텍스트
# ════════════════════════════════════════════════════════════════

def build_section_condition(section_key: str, survey: dict) -> str:
    """섹션별 개인화된 condition 문장 (서브섹션 키 지원: lifestyle.smoking 등)"""
    # 서브섹션 키 처리: "lifestyle.smoking" → sub_key = "smoking"
    _sub_key = section_key.split(".")[-1] if "." in section_key else ""

    if _sub_key == "smoking":
        smoking = survey.get("smoking_status", "")
        if smoking and ("현재" in str(smoking) or "current" in str(smoking).lower()):
            return "흡연 습관이 있으므로, 하루 흡연량을 절반으로 줄여 유지하면"
        return "흡연이 피부에 미치는 영향을 줄이기 위해 금연 방향으로 노력하면"

    if _sub_key == "drinking":
        drinking = survey.get("drinking_days_per_week")
        if drinking is not None:
            try:
                d = int(drinking)
                if d >= 3:
                    return f"주 {d}일 음주하는 편이므로, 이를 주 1일로 줄여 유지하면"
                elif d > 0:
                    return f"주 {d}일 음주하는 편이므로, 음주량을 조금만 줄여 유지하면"
            except (ValueError, TypeError):
                pass
        return "음주 빈도를 줄여 유지하면"

    if _sub_key == "stress":
        stress = survey.get("stress_score")
        if stress is not None:
            try:
                s = float(stress)
                if s >= 7:
                    return f"스트레스 수준이 {s:.0f}/10점으로 높은 편이므로, 이를 5점 이하로 낮춰 유지하면"
                elif s >= 4:
                    return f"스트레스 수준이 {s:.0f}/10점인 편이므로, 이를 조금 더 낮춰 유지하면"
            except (ValueError, TypeError):
                pass
        return "스트레스를 줄여 유지하면"

    if section_key == "sleep":
        hours = survey.get("sleep_hours_weekday")
        if hours is not None:
            try:
                h = float(hours)
                quality = survey.get("sleep_quality_score")
                if h < 6:
                    return "수면 시간이 부족한 편이므로, 이를 7시간 안팎으로 늘려 유지하면"
                elif 6 <= h < 7:
                    return "수면 시간을 조금만 늘려 최소 7시간으로 맞춰 유지하면"
                elif h >= 7 and quality is not None:
                    if float(quality) < 6:
                        return "수면 시간은 충분하지만 수면의 질이 낮은 편이므로, 깊은 수면 비율을 높여 유지하면"
            except (ValueError, TypeError):
                pass
        return "현재의 수면 리듬을 깨지 않도록 유지하면"

    elif section_key == "uv":
        sunscreen = survey.get("sunscreen_frequency", "")
        sunscreen_low = ["거의 안 씀", "외출 시 가끔", "가끔", "안 씀", "거의 안씀", "never", "안함"]
        sunscreen_str = str(sunscreen).lower() if sunscreen else ""
        if sunscreen and any(low.lower() in sunscreen_str for low in sunscreen_low):
            return "선크림 사용이 드문 편이므로, 외출할 때마다 바르는 습관을 유지하면"
        exposure = survey.get("uv_exposure_10to16", "")
        exposure_str = str(exposure).lower() if exposure else ""
        if exposure and ("거의 매일" in str(exposure) or "매일" in str(exposure) or "daily" in exposure_str):
            return "낮 시간대 야외 노출이 잦은 편이므로, 이 시간대 노출을 줄여 유지하면"
        return "현재의 자외선 관리 습관을 조금만 강화해 유지하면"

    elif section_key == "lifestyle":
        smoking = survey.get("smoking_status", "")
        if smoking and ("현재" in str(smoking) or "current" in str(smoking).lower()):
            return "흡연 습관이 있으므로, 하루 흡연량을 절반으로 줄여 유지하면"
        stress = survey.get("stress_score")
        if stress is not None:
            try:
                if float(stress) >= 7:
                    return "스트레스 수준이 높은 편이므로, 이를 5점 이하로 낮춰 유지하면"
            except (ValueError, TypeError):
                pass
        drinking = survey.get("drinking_days_per_week")
        if drinking is not None:
            try:
                if int(drinking) >= 3:
                    return "주당 음주 빈도가 높은 편이므로, 이를 주 1일로 줄여 유지하면"
            except (ValueError, TypeError):
                pass
        return "현재의 생활습관을 조금만 개선해 유지하면"

    elif section_key == "activity":
        resistance = survey.get("resistance_weekly")
        if resistance is not None:
            try:
                if int(resistance) == 0:
                    return "근력 운동이 부족한 편이므로, 주 1회 20분만 추가해 유지하면"
            except (ValueError, TypeError):
                pass
        aerobic = survey.get("aerobic_weekly")
        if aerobic is not None:
            try:
                if int(aerobic) < 2:
                    return "유산소 운동 빈도가 낮은 편이므로, 이를 주 3회로 늘려 유지하면"
            except (ValueError, TypeError):
                pass
        return "현재의 운동 패턴을 조금만 강화해 유지하면"

    elif section_key == "goals":
        outcomes = survey.get("outcomes", [])
        if outcomes:
            if len(outcomes) <= 2:
                labels = [OUTCOME_LABELS.get(o, o) for o in outcomes[:2]]
                return f"선택하신 '{', '.join(labels)}' 목표에 맞춰 관리 습관을 조금만 강화해 유지하면"
            return "피부 목표 전반을 기준으로 생활습관을 조금만 교정해 유지하면"
        return "피부 목표에 맞춰 관리 습관을 조금만 강화해 유지하면"

    return "현재의 관리 습관을 유지하면"


def format_simulation_text(section_key: str, survey: dict, section_quant: dict) -> tuple[str, dict]:
    """simulation 카드 텍스트 생성"""
    mode = section_quant.get("mode", "estimated")
    stats_by_outcome = section_quant.get("stats_by_outcome", {})
    condition = build_section_condition(section_key, survey)
    meta: Dict[str, Any] = {"mode": mode}

    if mode == "grounded" and stats_by_outcome:
        parts: List[str] = []
        for outcome, stats in stats_by_outcome.items():
            if isinstance(stats, dict) and "timeframe_groups" in stats:
                timeframe_groups = stats["timeframe_groups"]
                if not timeframe_groups:
                    continue
                tf_days = list(timeframe_groups.keys())[0]
                group = timeframe_groups[tf_days]
                tf_label = timeframe_days_to_label(tf_days)
                outcome_label = OUTCOME_LABELS.get(outcome, outcome)
                median = group.get("median", group.get("mean", 0))
                min_val = group.get("min", 0)
                max_val = group.get("max", 0)
                parts.append(
                    f"{outcome_label} {tf_label} 뒤 중앙값 {median:.1f}%(범위 {min_val:.1f}~{max_val:.1f}%)"
                )
                print(f"    📊 [{section_key}] condition=\"{condition}\", tf={tf_label}, outcome={outcome_label}")
        if parts:
            text = (
                f"{condition} 연구에서는 "
                + ", ".join(parts)
                + " 등이 각각 변화하는 경향이 관찰되었습니다."
            )
            return text, meta
        return f"{condition} 정량 근거를 바탕으로 예상되는 변화입니다.", meta

    elif mode == "estimated" and "estimated" in stats_by_outcome:
        est = stats_by_outcome["estimated"]
        tf_label = est.get("timeframe_label", "12주")
        selected_outcomes = section_quant.get("selected_outcomes", [])
        if selected_outcomes:
            outcome_label = OUTCOME_LABELS.get(selected_outcomes[0], "피부 상태")
        else:
            _map = {"sleep": "수분 장벽", "uv": "색소침착", "lifestyle": "여드름", "activity": "탄력", "goals": "피부 상태"}
            outcome_label = _map.get(section_key, "피부 상태")

        median = est.get("median", 0)
        min_val = est.get("min", 0)
        max_val = est.get("max", 0)
        text = (
            f"{condition} {tf_label} 뒤에는, 정량 근거가 부족해 논문 전반을 바탕으로 보수적으로 보면 "
            f"{outcome_label}이(가) 대략 {median:.1f}% 안팎(범위 {min_val:.1f}~{max_val:.1f}%) 변화할 수 있습니다."
        )
        meta["disclaimer_small"] = "이 수치는 개별 연구를 평균낸 값이 아니라, 논문 전반을 바탕으로 한 AI 추정치입니다."
        print(f"    📊 [{section_key}] condition=\"{condition}\", tf={tf_label}, outcome={outcome_label} (estimated)")
        return text, meta

    # 정량 데이터가 전혀 없어도 섹션별 의미 있는 예측 텍스트 생성
    _section_base = section_key.split(".")[0]  # "lifestyle.smoking" → "lifestyle"
    _sub_key = section_key.split(".")[-1] if "." in section_key else ""
    _outcome_map = {
        "sleep": "피부 수분 장벽",
        "uv": "색소침착 방어력",
        "lifestyle": "피부 염증 지표",
        "activity": "피부 탄력",
        "goals": "전반적 피부 상태",
        "smoking": "피부 노화 속도",
        "drinking": "피부 염증 수준",
        "stress": "피부 스트레스 반응",
    }
    _outcome_label = _outcome_map.get(_sub_key, _outcome_map.get(_section_base, "피부 상태"))
    meta["mode"] = "estimated"
    meta["disclaimer_small"] = "정량 근거가 부족해 논문 전반을 바탕으로 AI가 보수적으로 추정한 내용입니다. 개인차가 큽니다."
    text = (
        f"{condition} 12주 뒤에는, 논문 기반으로 보수적으로 추정했을 때 "
        f"{_outcome_label}이(가) 점진적으로 개선될 것으로 기대됩니다."
    )
    print(f"    📊 [{section_key}] condition=\"{condition}\", outcome={_outcome_label} (no-quant fallback)")
    return text, meta


# ════════════════════════════════════════════════════════════════
#  설문 값 / evidence 키워드 주입
# ════════════════════════════════════════════════════════════════

def _extract_required_survey_values(section: str, survey: dict) -> List[str]:
    values: List[str] = []
    if section == "sleep":
        h = survey.get("sleep_hours_weekday")
        q = survey.get("sleep_quality_score")
        if h is not None:
            values.append(f"{h}시간")
        if q is not None:
            values.append(f"{q}/10점")
    elif section == "uv":
        if survey.get("uv_exposure_10to16"):
            values.append(str(survey["uv_exposure_10to16"]))
        if survey.get("sunscreen_frequency"):
            values.append(str(survey["sunscreen_frequency"]))
    elif section == "lifestyle":
        if survey.get("stress_score") is not None:
            values.append(f"{survey['stress_score']}/10점")
        if survey.get("drinking_days_per_week") is not None:
            values.append(f"{survey['drinking_days_per_week']}일")
        if survey.get("smoking_status"):
            values.append(str(survey["smoking_status"]))
    elif section == "activity":
        if survey.get("aerobic_weekly") is not None:
            values.append(f"{survey['aerobic_weekly']}회")
        if survey.get("resistance_weekly") is not None:
            values.append(f"{survey['resistance_weekly']}회")
    elif section == "goals":
        outcomes = survey.get("outcomes", [])
        values.extend([OUTCOME_LABELS.get(o, o) for o in outcomes])
    return values


def _extract_required_profile_values(user_profile: dict) -> List[str]:
    values = []
    if user_profile.get("gender"):
        gender_label = "남성" if user_profile["gender"].lower() in ["male", "m", "남성", "남"] else "여성"
        values.append(gender_label)
    if user_profile.get("age_bucket"):
        values.append(user_profile["age_bucket"])
    if user_profile.get("bmi_category"):
        values.append(user_profile["bmi_category"])
    return values


def _extract_evidence_keywords_from_quant(quant_results: dict, section: str) -> List[str]:
    keywords = []
    selected_outcomes = quant_results.get("selected_outcomes", [])
    for outcome in selected_outcomes[:2]:
        keywords.append(OUTCOME_LABELS.get(outcome, outcome))
    return keywords


def _force_inject(text: str, required: List[str], label: str) -> str:
    """필수 값이 텍스트에 없으면 끝에 추가"""
    if not required:
        return text
    for v in required:
        if v in text:
            return text
    return text + f" ({label}: {', '.join(required)})"


# ════════════════════════════════════════════════════════════════
#  카드 meta 빌더 (Traceability)
# ════════════════════════════════════════════════════════════════

def _collect_evidence_chunk_ids(evidence_map: Dict, card_type: str) -> List[str]:
    """카드 타입별 evidence chunk_id 수집 (최대 3개).

    우선순위:
      1) extracted_claims[card_type].support[*].chunk_id
      2) narrative_evidence[card_type][*].chunk_id
    simulation 카드는 action > cause > problem 순서로 통합 수집.
    """
    if not evidence_map:
        return []

    types_to_check = (
        ["action", "cause", "problem"] if card_type == "simulation" else [card_type]
    )

    chunk_ids: List[str] = []
    seen: set = set()

    for ct in types_to_check:
        # Priority 1: extracted_claims
        for claim in evidence_map.get("extracted_claims", {}).get(ct, []):
            for support in claim.get("support", []):
                cid = support.get("chunk_id", "")
                if cid and cid not in seen:
                    chunk_ids.append(cid)
                    seen.add(cid)
                    if len(chunk_ids) >= 3:
                        return chunk_ids

        # Priority 2: narrative_evidence
        for item in evidence_map.get("narrative_evidence", {}).get(ct, []):
            cid = getattr(item, "chunk_id", None)
            if cid is None and isinstance(item, dict):
                cid = item.get("chunk_id", "")
            if cid and cid not in seen:
                chunk_ids.append(cid)
                seen.add(cid)
                if len(chunk_ids) >= 3:
                    return chunk_ids

    return chunk_ids


def _build_quant_refs_summary(section_quant: dict) -> List[Dict[str, Any]]:
    """section_quant → meta용 정량 근거 요약 (최대 6개, 본문 노출 아님)."""
    refs: List[Dict[str, Any]] = []
    stats_by_outcome = section_quant.get("stats_by_outcome", {})

    for outcome, stats in stats_by_outcome.items():
        if outcome == "estimated":
            refs.append({
                "outcome": "estimated",
                "timeframe_days": stats.get("timeframe_days"),
                "effect_unit": "%",
                "median": round(stats.get("median", 0), 1),
                "count": stats.get("count", 0),
                "p_label": "estimated",
            })
            continue

        if not isinstance(stats, dict) or "timeframe_groups" not in stats:
            continue

        for tf_days, group in stats.get("timeframe_groups", {}).items():
            cards_data = group.get("cards", [])
            median = group.get("median", group.get("mean", 0))
            p_labels = [c.get("p_label", "") for c in cards_data if c.get("p_label")]
            refs.append({
                "outcome": outcome,
                "timeframe_days": tf_days,
                "effect_unit": "%",
                "median": round(median, 1) if isinstance(median, (int, float)) else 0,
                "count": len(cards_data),
                "p_label": p_labels[0] if p_labels else "",
            })

    return refs[:6]  # outcome 3개 × timeframe 2개 반영


def _build_card_meta(
    card_type: str,
    section_quant: dict,
    evidence_map: Optional[Dict] = None,
) -> Dict[str, Any]:
    """개별 카드의 meta 딕셔너리 기본 골격 생성."""
    selected_outcomes = section_quant.get("selected_outcomes", [])[:3]

    # 대표 timeframe
    tf_days_val: Optional[float] = None
    tf_label_val: Optional[str] = None
    for outcome_stats in section_quant.get("stats_by_outcome", {}).values():
        if isinstance(outcome_stats, dict) and "timeframe_groups" in outcome_stats:
            tfs = list(outcome_stats["timeframe_groups"].keys())
            if tfs:
                tf_days_val = tfs[0]
                tf_label_val = timeframe_days_to_label(tfs[0])
                break
    if tf_days_val is None:
        est = section_quant.get("stats_by_outcome", {}).get("estimated")
        if isinstance(est, dict):
            tf_days_val = est.get("timeframe_days")
            tf_label_val = est.get("timeframe_label")

    return {
        "outcomes": selected_outcomes,
        "timeframe_label": tf_label_val,
        "timeframe_days": tf_days_val,
        "evidence_chunk_ids": _collect_evidence_chunk_ids(evidence_map or {}, card_type),
        "quant_refs": _build_quant_refs_summary(section_quant),
        "grounding_mode": section_quant.get("mode", "estimated"),
    }


def _ensure_card_meta(
    processed: Dict[str, Any],
    card_type: str,
    section_quant: dict,
    evidence_map: Optional[Dict],
) -> None:
    """카드에 meta를 보장하고, simulation에서는 mode/disclaimer를 자동 보정 (in-place)."""
    base_meta = _build_card_meta(card_type or "", section_quant, evidence_map)
    existing_meta = processed.get("meta") or {}
    if not isinstance(existing_meta, dict):
        existing_meta = {}

    # base_meta를 기본, 기존 meta 값(빈 문자열/None 제외)을 우선
    merged = {**base_meta}
    for k, v in existing_meta.items():
        if v is not None and v != "":
            merged[k] = v

    # simulation 특수 처리: mode ↔ grounding_mode 동기화
    if card_type == "simulation":
        if "mode" in merged and merged.get("mode"):
            merged["grounding_mode"] = merged["mode"]
        elif "grounding_mode" in merged and merged.get("grounding_mode"):
            merged["mode"] = merged["grounding_mode"]
        if not merged.get("mode"):
            merged["mode"] = "estimated"
            merged["grounding_mode"] = "estimated"
        # estimated → disclaimer_small 자동 보정
        if merged.get("mode") == "estimated" and not merged.get("disclaimer_small"):
            merged["disclaimer_small"] = (
                "정량 근거가 부족해 논문 전반을 바탕으로 AI가 보수적으로 추정한 값입니다. 개인차가 큽니다."
            )

    processed["meta"] = merged


# ════════════════════════════════════════════════════════════════
#  카드 후처리 (메인)
# ════════════════════════════════════════════════════════════════

def postprocess_cards(
    cards: List[Dict[str, Any]],
    section_quant: dict,
    section_key: str = "",
    survey: dict = None,
    user_profile: dict = None,
    evidence_map: Optional[Dict] = None,
) -> tuple[List[Dict[str, Any]], Dict[str, bool]]:
    """카드 후처리: 길이 제한, PMC 제거, simulation 템플릿, 설문 수치 주입, meta 삽입"""
    quality_flags: Dict[str, bool] = {"leaked_citation": False}
    processed_cards = []
    survey = survey or {}
    user_profile = user_profile or {}

    # composite key ("lifestyle.smoking") → base section ("lifestyle")로 설문/프로필 추출
    _base_section = section_key.split(".")[0] if "." in section_key else section_key
    req_survey = _extract_required_survey_values(_base_section, survey)
    req_profile = _extract_required_profile_values(user_profile)
    req_evidence = _extract_evidence_keywords_from_quant(section_quant, _base_section)

    for card in cards:
        card_type = card.get("type")
        processed = {**card}

        if card_type in ["problem", "cause"]:
            text = strip_markdown(card.get("text", ""))
            text, leaked = remove_citation_leaks(text)
            if leaked:
                quality_flags["leaked_citation"] = True
            text = soften_overconfident_language(text)
            processed["text"] = limit_sentences(text, max_sentences=3)

        elif card_type == "simulation":
            # LLM 생성 텍스트 우선 사용 (placeholder/누락 시에만 템플릿 fallback)
            llm_text = strip_markdown((card.get("text") or "").strip())
            _placeholders = ("정확히 2-4문장만", "정량 근거가 부족해 보수적으로 추정한 값입니다.")
            use_llm = llm_text and len(llm_text) >= 25 and not any(p in llm_text for p in _placeholders)

            template_text, sim_meta = format_simulation_text(section_key, survey, section_quant)
            text = llm_text if use_llm else template_text

            text, leaked = remove_citation_leaks(text)
            if leaked:
                quality_flags["leaked_citation"] = True
            text = soften_overconfident_language(text)
            processed["text"] = limit_sentences(text, max_sentences=4)
            if "meta" not in processed:
                processed["meta"] = {}
            processed["meta"].update(sim_meta)
            if sim_meta.get("mode") == "estimated" and "disclaimer_small" not in processed["meta"]:
                processed["meta"]["disclaimer_small"] = (
                    "정량 근거가 부족해 논문 전반을 바탕으로 AI가 보수적으로 추정한 값입니다. 개인차가 큽니다."
                )

        elif card_type == "action":
            items = card.get("items", [])
            while len(items) < 3:
                items.append({"title": "행동", "detail": "분석 중입니다."})
            items = items[:3]

            processed_items = []
            for item in items:
                title = strip_markdown(item.get("title", "") or "행동")
                detail = strip_markdown(item.get("detail", "") or "설명 없음")

                title, leaked1 = remove_citation_leaks(title)
                detail, leaked2 = remove_citation_leaks(detail)
                if leaked1 or leaked2:
                    quality_flags["leaked_citation"] = True

                title = soften_overconfident_language(title)
                detail = soften_overconfident_language(detail)

                # 설문/근거/프로필 키워드는 meta에 트래킹되므로 본문에 주입하지 않음
                # (기존 _force_inject 호출 제거)

                title = limit_sentences(title, max_sentences=1)
                detail = limit_sentences(detail, max_sentences=1)

                if not detail or len(detail) < 5:
                    detail = item.get("detail", "설명 없음")
                    detail, _ = remove_citation_leaks(detail)

                processed_items.append({"title": title, "detail": detail})
            processed["items"] = processed_items

        # ── 카드 meta 보장 (Traceability) ──
        _ensure_card_meta(processed, card_type, section_quant, evidence_map)

        processed_cards.append(processed)

    # 디버그: meta 존재 확인
    if REPORT_DEBUG:
        for i, card in enumerate(processed_cards):
            ct = card.get("type", "?")
            meta = card.get("meta", {})
            n_chunks = len(meta.get("evidence_chunk_ids", []))
            n_qrefs = len(meta.get("quant_refs", []))
            print(f"    🔗 [{section_key}.{ct}] meta: outcomes={meta.get('outcomes', [])}, "
                  f"chunks={n_chunks}, qrefs={n_qrefs}, grounding={meta.get('grounding_mode', 'N/A')}")

    return processed_cards, quality_flags


# ════════════════════════════════════════════════════════════════
#  품질 검증
# ════════════════════════════════════════════════════════════════

def validate_section_cards(
    section: str, cards: List[Dict[str, Any]],
    survey: dict, user_profile: dict, section_claims: dict,
) -> Dict[str, Any]:
    """섹션 카드 품질 검증"""
    if len(cards) != 4:
        return {"passed": False, "reason": f"카드 수가 4장이 아님 ({len(cards)}장)"}

    # 필수 타입
    found_types = {c.get("type") for c in cards}
    required_types = {"problem", "cause", "action", "simulation"}
    if not required_types.issubset(found_types):
        return {"passed": False, "reason": f"필수 카드 타입 누락: {required_types - found_types}"}

    # 금지 토큰 확인
    for card in cards:
        texts = [card.get("text", "")]
        for item in card.get("items", []):
            texts.extend([item.get("title", ""), item.get("detail", "")])
        if check_forbidden_patterns(" ".join(texts)):
            return {"passed": False, "reason": f"금지 토큰 누출: {card.get('type')} 카드"}

    # simulation meta (soft check: postprocess에서 자동 보정되므로 hard fail 아님)
    for sim in (c for c in cards if c.get("type") == "simulation"):
        meta = sim.get("meta", {})
        if not meta or "mode" not in meta:
            print(f"  ⚠️ [{section}] simulation meta.mode 없음 (후처리에서 보정 예정)")
        elif meta.get("mode") == "estimated":
            disclaimer = meta.get("disclaimer_small", "")
            if not disclaimer or not disclaimer.strip():
                print(f"  ⚠️ [{section}] estimated인데 disclaimer_small 없음 (후처리에서 보정 예정)")

    # 설문값 반영 확인
    all_texts = []
    for card in cards:
        texts = [card.get("text", "")]
        for item in card.get("items", []):
            texts.extend([item.get("title", ""), item.get("detail", "")])
        all_texts.append(" ".join(texts))

    if not check_survey_values_in_text(" ".join(all_texts), section, survey):
        return {"passed": False, "reason": "필수 설문값이 카드에 반영되지 않음"}

    return {"passed": True, "reason": "모든 검증 통과"}


def check_survey_values_in_text(text: str, section: str, survey: dict) -> bool:
    """텍스트에 설문 값이 반영되었는지 확인"""
    if section == "sleep":
        hours = survey.get("sleep_hours_weekday")
        if hours is not None:
            if str(int(hours)) in text or str(hours) in text or "부족" in text or "충분" in text or "수면" in text:
                return True
    elif section == "uv":
        sunscreen = survey.get("sunscreen_frequency", "")
        if sunscreen:
            # 선크림 관련 언급이 있으면 통과
            if "선크림" in text or "자외선" in text or "UV" in text or "SPF" in text:
                return True
        else:
            # 선크림 정보가 없으면 자외선 관련 내용만 있어도 통과
            return "자외선" in text or "UV" in text
    elif section == "lifestyle":
        stress = survey.get("stress_score")
        if stress is not None:
            if str(int(stress)) in text or "스트레스" in text:
                return True
    elif section == "activity":
        aerobic = survey.get("aerobic_weekly")
        if aerobic is not None:
            if str(aerobic) in text or "운동" in text:
                return True
    elif section == "goals":
        # goals 섹션은 outcome 관련 키워드가 있으면 통과
        outcomes = survey.get("outcomes", [])
        if not outcomes:
            return True  # 선택된 outcome이 없으면 무조건 통과
        for o in outcomes:
            label = OUTCOME_LABELS.get(o, o)
            if label in text:
                return True
        # outcome 라벨이 없더라도, 피부 관련 키워드가 있으면 통과
        skin_keywords = ["피부", "수분", "탄력", "주름", "노화", "장벽", "여드름", "색소", "홍조"]
        if any(kw in text for kw in skin_keywords):
            return True
    return False


def extract_evidence_keywords(section_claims: dict) -> List[str]:
    """claims에서 evidence 키워드 추출"""
    keywords = []
    for card_type in ["problem", "cause", "action"]:
        for claim_data in section_claims.get(card_type, []):
            for support in claim_data.get("support", []):
                words = support.get("support_text", "").split()
                keywords.extend([w for w in words if len(w) > 2][:3])
    return list(set(keywords))[:10]


def check_forbidden_patterns(text: str) -> bool:
    """금지 패턴 확인 (PMC/PMID/p=/CI + 과도한 일반론)"""
    forbidden = [r'PMC\d+', r'PMID\s*:?\s*\d+', r'p\s*[=<>]\s*[\d.]+', r'CI\s*:?\s*\[', r'confidence interval']
    for pattern in forbidden:
        if re.search(pattern, text, re.IGNORECASE):
            return True
    generic_phrases = ["~하면 좋습니다", "~하는 것이 중요합니다", "~하는 것을 권장합니다"]
    if sum(1 for p in generic_phrases if p in text) >= 3:
        return True
    return False


def check_overconfident_language(text: str) -> bool:
    """지나친 확신 표현 확인"""
    return any(phrase in text for phrase in ["반드시", "확실히", "절대적으로", "100%", "필수적으로"])
