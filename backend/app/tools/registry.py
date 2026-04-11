"""
Tool Registry — MCP 대비 도구 레이어

목적: 나중에 MCP tool로 노출할 때 챗봇 로직을 거의 안 바꾸게 한다.
- 도구는 id / name / description / input_schema / run() 으로 구성
- ToolRegistry 에 등록하고, run(tool_id, payload, context) 로 실행
"""

from typing import Dict, Any, List, Optional, Type, Tuple
from pydantic import BaseModel, Field
from abc import ABC, abstractmethod
from datetime import date, timedelta


# ══════════════════════════════════════════════
#  기본 인터페이스
# ══════════════════════════════════════════════

class ToolContext(BaseModel):
    """도구 실행 컨텍스트"""
    user_id: Optional[int] = None
    session_id: Optional[str] = None
    report_id: Optional[int] = None


class ToolResult(BaseModel):
    """도구 실행 결과"""
    success: bool
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None


class BaseTool(ABC):
    """도구 기본 클래스"""
    id: str = ""
    name: str = ""
    description: str = ""
    input_schema: Type[BaseModel] = BaseModel

    @abstractmethod
    async def run(self, payload: BaseModel, context: ToolContext) -> ToolResult:
        ...

    def to_spec(self) -> Dict[str, Any]:
        """MCP 호환 도구 스펙 반환"""
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "input_schema": self.input_schema.model_json_schema(),
        }


class ToolRegistry:
    """도구 레지스트리 — 등록 · 조회 · 실행"""

    def __init__(self):
        self._tools: Dict[str, BaseTool] = {}

    def register(self, tool: BaseTool):
        self._tools[tool.id] = tool

    def get(self, tool_id: str) -> Optional[BaseTool]:
        return self._tools.get(tool_id)

    def list_tools(self) -> List[Dict[str, Any]]:
        return [t.to_spec() for t in self._tools.values()]

    async def run(
        self, tool_id: str, payload: Dict[str, Any], context: ToolContext
    ) -> ToolResult:
        tool = self._tools.get(tool_id)
        if not tool:
            return ToolResult(success=False, error=f"도구를 찾을 수 없음: {tool_id}")
        try:
            parsed = tool.input_schema(**payload)
            return await tool.run(parsed, context)
        except Exception as e:
            return ToolResult(success=False, error=str(e))

    def to_langchain_tools(self, context: Optional[ToolContext] = None):
        """
        등록된 BaseTool들을 LangChain StructuredTool 리스트로 변환.
        LangGraph agent의 bind_tools()에 그대로 전달 가능.
        """
        import asyncio
        import json as _json
        from langchain_core.tools import StructuredTool

        ctx = context or ToolContext()
        lc_tools = []

        for tool_id, tool in self._tools.items():
            # 각 도구마다 클로저로 감싸서 langchain이 호출할 수 있게 함
            _tool = tool  # 클로저 캡처

            async def _arun(__payload_str: str, *, _t=_tool) -> str:
                """LangChain이 호출하는 비동기 함수"""
                try:
                    payload = _json.loads(__payload_str) if isinstance(__payload_str, str) else __payload_str
                except Exception:
                    payload = {}
                result = await _t.run(_t.input_schema(**payload), ctx)
                return _json.dumps(result.data if result.success else {"error": result.error}, ensure_ascii=False)

            def _run(__payload_str: str, *, _t=_tool) -> str:
                """동기 fallback"""
                return asyncio.get_event_loop().run_until_complete(_arun(__payload_str, _t=_t))

            lc_tool = StructuredTool.from_function(
                func=_run,
                coroutine=_arun,
                name=tool_id,
                description=_tool.description,
                args_schema=_tool.input_schema,
            )
            lc_tools.append(lc_tool)

        return lc_tools


# ══════════════════════════════════════════════
#  내장 도구 1) save_goal — 코치 목표 저장
# ══════════════════════════════════════════════

class SaveGoalInput(BaseModel):
    goal: str = Field(..., description="사용자의 피부 관리 목표")


class SaveGoalTool(BaseTool):
    id = "save_goal"
    name = "목표 저장"
    description = "코치 목표를 저장합니다 (예: '색소 개선', '장벽 회복')"
    input_schema = SaveGoalInput

    async def run(self, payload: SaveGoalInput, context: ToolContext) -> ToolResult:
        # 실제 저장은 coach_service 에서 session.coach_memory 를 통해 수행
        return ToolResult(
            success=True,
            data={"goal": payload.goal, "saved": True},
        )


# ══════════════════════════════════════════════
#  내장 도구 2) generate_today_plan — 오늘의 액션 플랜 생성
# ══════════════════════════════════════════════

class GenerateTodayPlanInput(BaseModel):
    focus: Optional[str] = Field(
        None, description="집중할 영역 (uv, sleep, hydration, stress, activity)"
    )


class GenerateTodayPlanTool(BaseTool):
    id = "generate_today_plan"
    name = "오늘의 플랜 생성"
    description = "오늘의 액션 플랜을 생성합니다 (규칙 기반)"
    input_schema = GenerateTodayPlanInput

    # 영역별 기본 액션
    _PLANS = {
        "uv": [
            {"action": "외출 30분 전 선크림 도포", "time": "아침", "difficulty": "easy"},
            {"action": "2~3시간마다 선크림 재도포", "time": "낮", "difficulty": "normal"},
            {"action": "선글라스 + 모자 착용", "time": "외출 시", "difficulty": "easy"},
        ],
        "sleep": [
            {"action": "카페인 오후 2시 이후 금지", "time": "오후", "difficulty": "normal"},
            {"action": "취침 1시간 전 스크린 OFF", "time": "밤", "difficulty": "normal"},
            {"action": "수면 환경 정비 (온도 18~20°C)", "time": "밤", "difficulty": "easy"},
        ],
        "hydration": [
            {"action": "수분 크림 레이어링", "time": "아침/밤", "difficulty": "easy"},
            {"action": "하루 물 1.5L 이상 섭취", "time": "종일", "difficulty": "normal"},
            {"action": "가습기 사용 (습도 40~60%)", "time": "실내", "difficulty": "easy"},
        ],
        "stress": [
            {"action": "5분 호흡 명상", "time": "아침", "difficulty": "easy"},
            {"action": "가벼운 산책 20분", "time": "점심", "difficulty": "easy"},
            {"action": "취침 전 스트레칭 10분", "time": "밤", "difficulty": "easy"},
        ],
        "activity": [
            {"action": "가벼운 유산소 30분 (걷기/조깅)", "time": "아침/저녁", "difficulty": "normal"},
            {"action": "스트레칭 또는 요가 15분", "time": "아침", "difficulty": "easy"},
            {"action": "계단 이용하기", "time": "종일", "difficulty": "easy"},
        ],
    }

    async def run(
        self, payload: GenerateTodayPlanInput, context: ToolContext
    ) -> ToolResult:
        focus = payload.focus or "uv"
        plan = self._PLANS.get(focus, self._PLANS["uv"])
        return ToolResult(
            success=True,
            data={"focus": focus, "date": str(date.today()), "actions": plan},
        )


# ══════════════════════════════════════════════
#  내장 도구 3) fetch_report_summary — 리포트 요약 조회
# ══════════════════════════════════════════════

class FetchReportSummaryInput(BaseModel):
    report_id: int = Field(..., description="리포트 ID (lifestyle_id)")


class FetchReportSummaryTool(BaseTool):
    id = "fetch_report_summary"
    name = "리포트 요약 조회"
    description = "report_id(lifestyle_id)로 리포트 요약을 반환합니다"
    input_schema = FetchReportSummaryInput

    def __init__(self, db_getter=None):
        self._get_db = db_getter

    async def run(
        self, payload: FetchReportSummaryInput, context: ToolContext
    ) -> ToolResult:
        if not self._get_db:
            return ToolResult(success=False, error="DB 접속 불가")
        try:
            from app.models import Lifestyle, Report

            db = next(self._get_db())
            report_row = (
                db.query(Report)
                .filter(Report.lifestyle_id == payload.report_id)
                .first()
            )
            if not report_row or not report_row.report:
                return ToolResult(success=False, error="리포트를 찾을 수 없음")

            summary = _extract_report_summary(report_row.report)
            return ToolResult(success=True, data=summary)
        except Exception as e:
            return ToolResult(success=False, error=str(e))


# ── 리포트 요약 추출 헬퍼 ──

def _extract_report_summary(report: Dict[str, Any]) -> Dict[str, Any]:
    """리포트 JSON에서 간략한 요약 dict 추출"""
    summary: Dict[str, Any] = {"tabs": [], "section_summaries": {}}
    if not isinstance(report, dict):
        return summary

    tabs = report.get("tabs", [])
    sections = report.get("sections", {})
    summary["tabs"] = tabs

    for tab in tabs:
        section = sections.get(tab, {})
        if not isinstance(section, dict):
            continue
        cards = section.get("cards", [])
        if not cards and section.get("subsections"):
            sub = section["subsections"][0] if section["subsections"] else {}
            cards = sub.get("cards", [])
        card_summaries = []
        for card in cards:
            ctype = card.get("type", "")
            text = card.get("text", "")[:120]
            if ctype == "action":
                items = card.get("items", [])
                text = "; ".join([i.get("title", "") for i in items[:3]])
            card_summaries.append({"type": ctype, "text": text})
        summary["section_summaries"][tab] = {
            "title": section.get("title", tab),
            "cards": card_summaries,
        }

    return summary


# ══════════════════════════════════════════════
#  내장 도구 4) get_habits_summary — 습관 체크인 요약 조회
# ══════════════════════════════════════════════

class GetHabitsSummaryInput(BaseModel):
    days: Optional[int] = Field(7, description="조회할 일수 (기본 7일)")


class GetHabitsSummaryTool(BaseTool):
    id = "get_habits_summary"
    name = "습관 실천 현황 조회"
    description = "사용자가 '할게요'로 선택한 습관과 최근 체크인(했어요/못했어요) 현황을 조회합니다. 실천률이 낮거나 연속 미실천 시 격려가 필요한 사용자 판단에 활용하세요."
    input_schema = GetHabitsSummaryInput

    def __init__(self, db_getter=None):
        self._get_db = db_getter

    async def run(
        self, payload: GetHabitsSummaryInput, context: ToolContext
    ) -> ToolResult:
        if not self._get_db or not context.user_id:
            return ToolResult(success=False, error="DB 또는 user_id 없음")
        try:
            from app.models import UserCommittedAction, ActionCheckIn

            db = next(self._get_db())
            days = min(max(payload.days or 7, 1), 30)
            today = date.today()
            from_date = today - timedelta(days=days)

            actions = (
                db.query(UserCommittedAction)
                .filter(
                    UserCommittedAction.user_id == context.user_id,
                    UserCommittedAction.status == "active",
                )
                .order_by(UserCommittedAction.committed_at.desc())
                .all()
            )
            if not actions:
                return ToolResult(
                    success=True,
                    data={
                        "habits": [],
                        "summary": "등록된 습관이 없습니다.",
                        "days": days,
                    },
                )

            action_ids = [a.id for a in actions]
            check_ins = (
                db.query(ActionCheckIn)
                .filter(
                    ActionCheckIn.committed_action_id.in_(action_ids),
                    ActionCheckIn.check_date >= from_date,
                    ActionCheckIn.check_date <= today,
                )
                .all()
            )

            by_action: Dict[int, List[Tuple[date, bool]]] = {
                aid: [] for aid in action_ids
            }
            for c in check_ins:
                by_action.setdefault(c.committed_action_id, []).append(
                    (c.check_date, c.completed)
                )
            for aid in by_action:
                by_action[aid].sort(key=lambda x: x[0], reverse=True)

            habits = []
            for a in actions:
                checks = by_action.get(a.id, [])
                completed_count = sum(1 for _, done in checks if done)
                total = len(checks)
                rate = (completed_count / total * 100) if total else 0
                today_done = next((c for d, c in checks if d == today), None)
                habits.append({
                    "action_title": a.action_title,
                    "section_key": a.section_key,
                    "completed_count": completed_count,
                    "total_days": total,
                    "rate_pct": round(rate, 1),
                    "today_completed": today_done,
                })
            summary = (
                f"최근 {days}일간 {len(habits)}개 습관 중 "
                f"평균 실천률 {sum(h['rate_pct'] for h in habits) / len(habits):.0f}%"
            )
            return ToolResult(
                success=True,
                data={"habits": habits, "summary": summary, "days": days},
            )
        except Exception as e:
            return ToolResult(success=False, error=str(e))


# ══════════════════════════════════════════════
#  레지스트리 팩토리
# ══════════════════════════════════════════════

def create_default_registry(db_getter=None) -> ToolRegistry:
    """기본 도구가 등록된 레지스트리 생성"""
    registry = ToolRegistry()
    registry.register(SaveGoalTool())
    registry.register(GenerateTodayPlanTool())
    registry.register(FetchReportSummaryTool(db_getter))
    registry.register(GetHabitsSummaryTool(db_getter))
    return registry
