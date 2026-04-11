"""
Action Plan 초기화 — 생활습관 개인화 + 도메인 분포 차트 데이터 생성
"""

from __future__ import annotations

import asyncio
import json
import os
import re
from datetime import date
from typing import Any, Dict, List, Optional


_DOMAIN_LABELS: Dict[str, str] = {
    "sleep": "수면",
    "activity": "운동",
    "uv": "자외선",
    "drinking": "음주",
    "smoking": "흡연",
    "stress": "스트레스",
    "goals": "피부루틴",
    "general": "기타",
}


# ── 도메인 차트 ──────────────────────────────────────────────────────────────

def build_domain_chart_data(
    all_actions: List[Any],
    new_action_ids: List[int],
) -> Dict[str, Any]:
    """before/after 도메인별 카운트를 반환합니다."""
    before: Dict[str, int] = {}
    after: Dict[str, int] = {}

    for a in all_actions:
        sk = a.section_key or "general"
        label = _DOMAIN_LABELS.get(sk, sk)
        after[label] = after.get(label, 0) + 1
        if a.id not in new_action_ids:
            before[label] = before.get(label, 0) + 1

    return {"before": before, "after": after}


# ── LLM 개인화 ───────────────────────────────────────────────────────────────

def _build_user_context(user: Any, lifestyle: Optional[Any], report_data: Optional[Dict]) -> Dict[str, Any]:
    ctx: Dict[str, Any] = {}

    if user.birthdate:
        today = date.today()
        age = today.year - user.birthdate.year - (
            (today.month, today.day) < (user.birthdate.month, user.birthdate.day)
        )
        ctx["age"] = age

    if user.gender:
        ctx["gender"] = user.gender
    if user.smoking_status:
        ctx["smoking_status"] = user.smoking_status

    if lifestyle:
        if getattr(lifestyle, "sleep_hours_weekday", None):
            ctx["sleep_hours"] = lifestyle.sleep_hours_weekday
        if getattr(lifestyle, "stress_score", None):
            ctx["stress_score"] = lifestyle.stress_score

    # 리포트 JSON에서 피부 타입/고민 추출 (구조가 다양할 수 있어 best-effort)
    if report_data:
        try:
            sections = report_data.get("sections", {})
            for section_val in sections.values():
                if not isinstance(section_val, dict):
                    continue
                for key in ("skin_type", "피부타입", "skinType"):
                    if section_val.get(key):
                        ctx.setdefault("skin_type", str(section_val[key]))
                for key in ("concerns", "피부고민", "skin_concerns"):
                    val = section_val.get(key)
                    if val and isinstance(val, list):
                        ctx.setdefault("skin_concerns", [str(c) for c in val[:3]])
        except Exception:
            pass

    return ctx


def _make_llm(temperature: float = 0.4):
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        return None
    model_name = os.getenv("COACH_LLM_MODEL", "gemini-2.5-flash")
    from langchain_google_genai import ChatGoogleGenerativeAI
    return ChatGoogleGenerativeAI(
        model=model_name,
        google_api_key=api_key,
        temperature=temperature,
        max_output_tokens=2048,
    )


async def _personalize_single(
    action_id: int,
    action_title: str,
    action_detail: Optional[str],
    section_key: str,
    ctx: Dict[str, Any],
) -> Dict[str, Any]:
    """단일 생활습관을 LLM으로 개인화합니다. 실패 시 원본 반환."""
    fallback = {
        "action_id": action_id,
        "original_title": action_title,
        "personalized_title": action_title,
        "personalized_detail": action_detail or "",
        "reason": "",
    }

    llm = _make_llm(0.4)
    if llm is None:
        return fallback

    profile_parts: List[str] = []
    if ctx.get("age"):
        profile_parts.append(f"나이 {ctx['age']}세")
    if ctx.get("gender"):
        profile_parts.append(f"성별 {ctx['gender']}")
    sm_map = {"never": "비흡연", "former": "과거흡연", "current": "현재흡연"}
    if ctx.get("smoking_status"):
        profile_parts.append(f"흡연 {sm_map.get(ctx['smoking_status'], ctx['smoking_status'])}")
    if ctx.get("skin_type"):
        profile_parts.append(f"피부타입 {ctx['skin_type']}")
    if ctx.get("skin_concerns"):
        profile_parts.append(f"피부고민 {', '.join(ctx['skin_concerns'])}")
    if ctx.get("sleep_hours"):
        profile_parts.append(f"평균수면 {ctx['sleep_hours']}시간")
    if ctx.get("stress_score"):
        profile_parts.append(f"스트레스 {ctx['stress_score']}/10")

    profile_text = " / ".join(profile_parts) if profile_parts else "정보 없음"
    domain_label = _DOMAIN_LABELS.get(section_key, section_key)

    prompt = (
        "당신은 피부 노화 관리 코치입니다. 사용자의 생활습관 실천 항목을 개인 데이터에 맞게 "
        "더 구체적이고 개인화하여 재작성해주세요.\n\n"
        f"사용자 프로필: {profile_text}\n"
        f"도메인: {domain_label}\n"
        f"원본 제목: {action_title}\n"
        f"원본 설명: {action_detail or '없음'}\n\n"
        "지침:\n"
        "1. 피부타입/고민/나이 등을 고려해 구체적인 방법·제품 타입·시간·빈도 등을 명시하세요\n"
        "2. title은 30자 이내, detail은 60자 이내\n"
        "3. 의학적 진단·처방 금지, '~일 수 있습니다' 형태 허용\n"
        "4. JSON 형식만 응답\n\n"
        '{"title": "...", "detail": "...", "reason": "왜 이렇게 개인화했는지 한 문장"}'
    )

    try:
        raw = await llm.ainvoke(prompt)
        text = raw.content if hasattr(raw, "content") else str(raw)
        print(f"[ActionPlan] LLM 응답 raw (action_id={action_id}): {text[:300]}")

        # 마크다운 코드 블록 제거 후 JSON 파싱 시도
        text_clean = re.sub(r"```(?:json)?", "", text).replace("```", "").strip()

        parsed = None
        # 1차: 전체를 바로 JSON 파싱
        try:
            parsed = json.loads(text_clean)
        except json.JSONDecodeError:
            pass

        # 2차: 첫 번째 { 부터 마지막 } 까지 추출
        if parsed is None:
            start = text_clean.find("{")
            end = text_clean.rfind("}")
            if start != -1 and end != -1 and end > start:
                try:
                    parsed = json.loads(text_clean[start:end + 1])
                except json.JSONDecodeError as je:
                    print(f"[ActionPlan] JSON 파싱 실패 action_id={action_id}: {je}")
                    print(f"[ActionPlan] 대상 텍스트: {text_clean[start:end + 1][:300]}")

        if parsed:
            result = {
                "action_id": action_id,
                "original_title": action_title,
                "personalized_title": str(parsed.get("title", action_title))[:50],
                "personalized_detail": str(parsed.get("detail", action_detail or ""))[:120],
                "reason": str(parsed.get("reason", ""))[:120],
            }
            print(f"[ActionPlan] 개인화 성공 action_id={action_id}: {result['personalized_title']}")
            return result
        else:
            print(f"[ActionPlan] JSON 추출 실패 action_id={action_id}, cleaned text: {text_clean[:300]}")
    except Exception as e:
        import traceback as _tb
        print(f"[ActionPlan] 개인화 실패 action_id={action_id}: {e}")
        _tb.print_exc()

    return fallback


async def personalize_habits_batch(
    actions: List[Any],
    user: Any,
    lifestyle: Optional[Any],
    report_data: Optional[Dict],
) -> List[Dict[str, Any]]:
    """여러 생활습관을 병렬 LLM 개인화합니다."""
    ctx = _build_user_context(user, lifestyle, report_data)
    tasks = [
        _personalize_single(
            action_id=a.id,
            action_title=a.action_title,
            action_detail=a.action_detail,
            section_key=a.section_key or "general",
            ctx=ctx,
        )
        for a in actions
    ]
    return await asyncio.gather(*tasks)


async def personalize_single_habit(
    action: Any,
    user: Any,
    lifestyle: Optional[Any],
    report_data: Optional[Dict],
) -> Dict[str, Any]:
    """단일 생활습관 재생성 (거절 후 1회 재시도)."""
    ctx = _build_user_context(user, lifestyle, report_data)
    return await _personalize_single(
        action_id=action.id,
        action_title=action.action_title,
        action_detail=action.action_detail,
        section_key=action.section_key or "general",
        ctx=ctx,
    )
