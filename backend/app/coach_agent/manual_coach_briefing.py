"""
챗봇에서 Quick → Coach 수동 전환 시: 스냅샷·실천 데이터 기반 균형 분석 + 권장 비율.
(action_plan / 리포트 직후 플로우에서는 호출하지 않음)
"""

from __future__ import annotations

import json
import uuid
from datetime import date, timedelta
from typing import List

from sqlalchemy.orm import Session

from app.coach_agent.context_loader import load_user_context_bundle
from app.coach_agent.llm_provider import get_coach_llm_provider
from app.models import DailyLifestyleSnapshot
from app.services.session_store import SessionData


def _fmt_rate(v) -> str:
    if v is None:
        return "?"
    try:
        x = float(v)
        return f"{x * 100:.0f}%"
    except (TypeError, ValueError):
        return "?"


def _snapshot_lines(rows: List[DailyLifestyleSnapshot], limit: int = 14) -> str:
    lines: List[str] = []
    for r in rows[:limit]:
        lines.append(
            f"{r.snapshot_date}: 수면{r.sleep_minutes}분 스트레스{r.stress_score} "
            f"유산소{r.aerobic_sessions_30min}근력{r.resistance_sessions_30min} "
            f"음주주{r.drinking_days_per_week} 흡연{r.smoking_status} UV{r.uv_outdoor_10to16}"
        )
    return "\n".join(lines) if lines else "(스냅샷 없음)"


async def run_manual_coach_briefing(
    session: SessionData,
    db: Session,
    send_json,
) -> None:
    """start → delta… → done. 실패 시 짧은 폴백 메시지."""
    uid = session.user_id
    assistant_msg_id = str(uuid.uuid4())
    await send_json(
        {
            "type": "start",
            "session_id": session.session_id,
            "assistant_message_id": assistant_msg_id,
        }
    )
    text = ""
    try:
        if not uid:
            raise ValueError("user_id 없음")

        bundle = await load_user_context_bundle(uid, db, session, report_ctx=None)
        end = date.today()
        start = end - timedelta(days=13)
        snap_rows = (
            db.query(DailyLifestyleSnapshot)
            .filter(
                DailyLifestyleSnapshot.user_id == uid,
                DailyLifestyleSnapshot.snapshot_date >= start,
                DailyLifestyleSnapshot.snapshot_date <= end,
            )
            .order_by(DailyLifestyleSnapshot.snapshot_date.desc())
            .all()
        )

        goals_txt = "\n".join(
            f"- {g.get('description') or g.get('goal_id', '')}: "
            f"7일달성 { _fmt_rate(g.get('success_rate_7d')) }"
            for g in (bundle.get("active_goals") or [])[:12]
        )
        logs_preview = "\n".join(
            str(x) for x in (bundle.get("recent_health_logs") or [])[:8]
        )

        prof = bundle.get("profile")
        try:
            if hasattr(prof, "model_dump"):
                prof_json = json.dumps(prof.model_dump(mode="json"), ensure_ascii=False)[:2200]
            else:
                prof_json = json.dumps(prof, ensure_ascii=False, default=str)[:2200]
        except Exception:
            prof_json = str(prof)[:2200]

        briefing_input = (
            f"[프로필 요약] {prof_json}\n"
            f"[활성 목표]\n{goals_txt or '(없음)'}\n"
            f"[최근 헬스 로그 샘플]\n{logs_preview or '(없음)'}\n"
            f"[최근 14일 일별 스냅샷]\n{_snapshot_lines(list(reversed(snap_rows)))}\n"
        )

        llm = get_coach_llm_provider()
        text = await llm.generate_lifestyle_balance_report(briefing_input)
        if not text.strip():
            text = "지금은 분석 문구를 만들기 어렵습니다. 잠시 후 다시 코치 모드로 전환해 보세요."

        chunk_size = 28
        for i in range(0, len(text), chunk_size):
            await send_json(
                {
                    "type": "delta",
                    "assistant_message_id": assistant_msg_id,
                    "delta": text[i : i + chunk_size],
                }
            )

        session.add_turn("user", "[코치 모드 전환] 생활·스냅샷 균형 분석을 요청했습니다.")
        session.add_turn("assistant", text)
    except Exception as e:
        print(f"[ManualCoachBriefing] 오류: {e}")
        err = (
            "생활 기록을 불러오는 중 문제가 있었어요. "
            "잠시 후 다시 시도하거나 메시지를 보내 주세요."
        )
        for i in range(0, len(err), 28):
            await send_json(
                {
                    "type": "delta",
                    "assistant_message_id": assistant_msg_id,
                    "delta": err[i : i + 28],
                }
            )
        session.add_turn("user", "[코치 모드 전환] 생활·스냅샷 균형 분석을 요청했습니다.")
        session.add_turn("assistant", err)
    finally:
        await send_json({"type": "done", "assistant_message_id": assistant_msg_id})
