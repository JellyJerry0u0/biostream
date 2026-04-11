"""
LLM 호출 추상화 — 프로바이더 교체 시 이 모듈만 갈아끼우면 된다.
"""

from __future__ import annotations

import json
import os
import re
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Sequence

from app.coach_agent.schemas import BehaviorPattern, InterventionPlan, StructuredCoachingResponse


class CoachLLMProvider(ABC):
    @abstractmethod
    async def enrich_behavior_patterns(
        self,
        metrics_json: Dict[str, Any],
        log_summary_lines: Sequence[str],
        existing_patterns: List[BehaviorPattern],
    ) -> List[BehaviorPattern]:
        """deterministic 패턴에 LLM 기반 패턴을 최대 2개까지 덧붙인다."""

    @abstractmethod
    async def generate_structured_coaching(
        self,
        user_message: str,
        profile_summary: str,
        metrics_json: Dict[str, Any],
        patterns_text: str,
        intervention_plan_json: Dict[str, Any],
        report_excerpt: str,
    ) -> StructuredCoachingResponse:
        ...

    @abstractmethod
    async def render_final_korean(
        self,
        structured: StructuredCoachingResponse,
        tone: str,
    ) -> str:
        """구조화 결과를 모바일용 평문(마크다운 없음)으로 다듬는다."""

    @abstractmethod
    async def generate_lifestyle_balance_report(self, briefing_input: str) -> str:
        """스냅샷·실천 요약 텍스트 → 강화/유지/완화 분석 + 영역별 권장 비율."""


def _strip_markdown(text: str) -> str:
    t = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    t = re.sub(r"^#+\s*", "", t, flags=re.MULTILINE)
    t = re.sub(r"^[\-\*]\s+", "", t, flags=re.MULTILINE)
    return t.strip()


class GeminiCoachLLMProvider(CoachLLMProvider):
    def __init__(self, model_name: str | None = None):
        self.model_name = model_name or os.getenv("COACH_LLM_MODEL", "gemini-2.5-flash")
        self._api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")

    def _llm(self, temperature: float = 0.4):
        from langchain_google_genai import ChatGoogleGenerativeAI

        if not self._api_key:
            raise ValueError("GEMINI_API_KEY 또는 GOOGLE_API_KEY 필요")
        return ChatGoogleGenerativeAI(
            model=self.model_name,
            google_api_key=self._api_key,
            temperature=temperature,
            max_output_tokens=8192,
        )

    async def enrich_behavior_patterns(
        self,
        metrics_json: Dict[str, Any],
        log_summary_lines: Sequence[str],
        existing_patterns: List[BehaviorPattern],
    ) -> List[BehaviorPattern]:
        from pydantic import BaseModel, Field

        class _Extra(BaseModel):
            summary: str
            domain: str
            evidence: List[str] = Field(default_factory=list)
            confidence: float = 0.5
            suggested_intervention_type: str = "micro_action"

        class _Wrap(BaseModel):
            patterns: List[_Extra] = Field(default_factory=list)

        llm = self._llm(0.3)
        try:
            structured = llm.with_structured_output(_Wrap)
        except Exception:
            structured = None

        prompt = (
            "너는 행동과학 관점의 코치다. 아래 수치 요약과 로그 한줄들만 보고 "
            "추가 행동 패턴을 최대 2개만 제시해라. 의학 진단 금지. 한국어 summary.\n"
            f"metrics: {json.dumps(metrics_json, ensure_ascii=False)[:2500]}\n"
            f"log_lines: {list(log_summary_lines)[:15]}\n"
            f"already: {[p.summary for p in existing_patterns]}\n"
        )
        out = list(existing_patterns)
        if structured:
            try:
                res: _Wrap = await structured.ainvoke(prompt)
                from app.coach_agent.schemas import GoalDomain, SuggestedInterventionType

                for p in res.patterns[:2]:
                    try:
                        dom = GoalDomain(p.domain)
                    except ValueError:
                        dom = GoalDomain.general
                    try:
                        st = SuggestedInterventionType(p.suggested_intervention_type)
                    except Exception:
                        st = SuggestedInterventionType.micro_action
                    from app.coach_agent.data_sources import new_episode_id

                    out.append(
                        BehaviorPattern(
                            pattern_id=new_episode_id(),
                            domain=dom,
                            summary=p.summary[:200],
                            evidence=p.evidence[:4],
                            confidence=max(0.0, min(1.0, p.confidence)),
                            suggested_intervention_type=st,
                        )
                    )
                return out[:8]
            except Exception:
                pass
        return out

    async def generate_structured_coaching(
        self,
        user_message: str,
        profile_summary: str,
        metrics_json: Dict[str, Any],
        patterns_text: str,
        intervention_plan_json: Dict[str, Any],
        report_excerpt: str,
    ) -> StructuredCoachingResponse:
        llm = self._llm(0.45)
        try:
            structured = llm.with_structured_output(StructuredCoachingResponse)
        except Exception:
            structured = None

        prompt = (
            "생활습관 코치. 의학적 진단·확정 금지. '~일 수 있습니다' 형태 허용.\n"
            "micro_actions는 실행 가능한 짧은 문장, 최대 3개.\n"
            f"user_message: {user_message}\n"
            f"profile: {profile_summary}\n"
            f"metrics: {json.dumps(metrics_json, ensure_ascii=False)[:2000]}\n"
            f"patterns:\n{patterns_text}\n"
            f"intervention_plan: {json.dumps(intervention_plan_json, ensure_ascii=False)[:2000]}\n"
            f"report_excerpt: {report_excerpt[:1200]}\n"
        )
        if structured:
            try:
                return await structured.ainvoke(prompt)
            except Exception:
                pass
        raw = await llm.ainvoke(prompt)
        text = raw.content if hasattr(raw, "content") else str(raw)
        return StructuredCoachingResponse(
            headline=text[:120],
            empathy_line="",
            rationale_short="",
            micro_actions=[],
        )

    async def render_final_korean(
        self,
        structured: StructuredCoachingResponse,
        tone: str,
    ) -> str:
        llm = self._llm(0.5)
        base = (
            f"headline: {structured.headline}\n"
            f"empathy: {structured.empathy_line}\n"
            f"why: {structured.rationale_short}\n"
            f"actions: {structured.micro_actions}\n"
            f"question: {structured.optional_question}\n"
            f"safety: {structured.safety_disclaimer_line}\n"
        )
        prompt = (
            "위 내용을 한국어 자연어 3~6문장으로 합쳐라. "
            "마크다운, 글머리표 기호, ** 굵게 금지. 죄책감 유발 금지. "
            f"톤: {tone}. "
            "행동은 많아도 3개까지. 첫 문장이 결론이 되게.\n\n"
            + base
        )
        raw = await llm.ainvoke(prompt)
        text = raw.content if hasattr(raw, "content") else str(raw)
        return _strip_markdown(text)

    async def generate_lifestyle_balance_report(self, briefing_input: str) -> str:
        from langchain_google_genai import ChatGoogleGenerativeAI

        if not self._api_key:
            raise ValueError("GEMINI_API_KEY 또는 GOOGLE_API_KEY 필요")
        llm = ChatGoogleGenerativeAI(
            model=self.model_name,
            google_api_key=self._api_key,
            temperature=0.35,
            max_output_tokens=8192,
        )
        prompt = (
            "너는 피부·건강 생활습관 코치다. 의학적 진단·확정 금지, '~일 수 있습니다' 허용.\n"
            "입력은 사용자 최근 일별 스냅샷·습관 실천 요약이다.\n\n"
            f"{briefing_input[:14000]}\n\n"
            "한국어로 답하라.\n"
            "먼저 5~10문장으로: (1) 강화·추가하면 좋은 영역 (2) 지금처럼 유지해도 되는 영역 "
            "(3) 이미 잘 지키고 있어 부담을 줄여도 되는 영역.\n"
            "그 다음 줄바꿈 후 소제목 '영역별 권장 비율' 아래에 "
            "수면, 활동·운동, 스트레스, UV·야외, 음주, 흡연·기타 등으로 나눈 권장 비율(%)을 "
            "한 줄씩 제시하고 합이 약 100%가 되게.\n"
            "마크다운, ** 굵게, # 제목 기호 금지."
        )
        raw = await llm.ainvoke(prompt)
        text = raw.content if hasattr(raw, "content") else str(raw)
        return _strip_markdown(text)


class HeuristicCoachLLMProvider(CoachLLMProvider):
    """API 키 없을 때 동작하는 폴백 (테스트·로컬)."""

    async def enrich_behavior_patterns(
        self,
        metrics_json: Dict[str, Any],
        log_summary_lines: Sequence[str],
        existing_patterns: List[BehaviorPattern],
    ) -> List[BehaviorPattern]:
        return existing_patterns

    async def generate_structured_coaching(
        self,
        user_message: str,
        profile_summary: str,
        metrics_json: Dict[str, Any],
        patterns_text: str,
        intervention_plan_json: Dict[str, Any],
        report_excerpt: str,
    ) -> StructuredCoachingResponse:
        actions = intervention_plan_json.get("today_actions") or [
            "오늘은 작은 행동 하나만 정해서 5분 안에 시작해 보기",
        ]
        return StructuredCoachingResponse(
            headline="오늘은 부담을 줄인 작은 한 걸음을 제안할 수 있어요.",
            empathy_line="변화를 시도하는 것만으로도 의미가 있어요.",
            rationale_short="한 번에 많은 것을 바꾸기보다 실행 가능한 크기가 유지에 도움이 될 수 있어요.",
            micro_actions=actions[:3],
            optional_question=intervention_plan_json.get("followup_question"),
            safety_disclaimer_line=None,
        )

    async def render_final_korean(
        self,
        structured: StructuredCoachingResponse,
        tone: str,
    ) -> str:
        parts = [structured.headline, structured.empathy_line, structured.rationale_short]
        for a in structured.micro_actions:
            parts.append(a)
        if structured.optional_question:
            parts.append(structured.optional_question)
        if structured.safety_disclaimer_line:
            parts.append(structured.safety_disclaimer_line)
        return " ".join(p for p in parts if p).strip()

    async def generate_lifestyle_balance_report(self, briefing_input: str) -> str:
        return (
            "최근 기록을 기준으로, 수면과 회복 리듬을 조금 더 챙기시면 좋고, "
            "이미 꾸준히 하시는 항목은 그대로 유지하셔도 돼요. "
            "과하게 완벽하게 지키는 영역은 부담만 줄여도 됩니다.\n\n"
            "영역별 권장 비율\n"
            "수면 28% / 활동·운동 22% / 스트레스 15% / UV·야외 15% / 음주 8% / 흡연·기타 12%"
        )


def get_coach_llm_provider() -> CoachLLMProvider:
    if os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY"):
        try:
            return GeminiCoachLLMProvider()
        except Exception:
            return HeuristicCoachLLMProvider()
    return HeuristicCoachLLMProvider()
