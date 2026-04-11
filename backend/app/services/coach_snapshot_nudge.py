"""
오늘 첫 일일 스냅샷 저장 후 백그라운드에서 코치 LangGraph 실행 → DB에 인앱 넛지 저장.
"""

from __future__ import annotations

import uuid

from app.coach_agent.runner import run_coach_agent
from app.database import SessionLocal
from app.models import CoachInAppNudge
from app.services.coach_service import load_report_context
from app.services.session_store import SessionData


async def run_snapshot_coach_nudge_for_user(user_id: int) -> None:
    db = SessionLocal()
    try:
        session = SessionData(session_id=str(uuid.uuid4()), user_id=user_id)
        session.engine = "coach"
        assistant_msg_id = str(uuid.uuid4())
        chunks: list[str] = []

        async def collect(data: dict) -> None:
            if data.get("type") == "delta":
                chunks.append(str(data.get("delta") or ""))

        await run_coach_agent(
            session=session,
            user_message=(
                "오늘 첫 생활 스냅샷이 저장되었습니다. "
                "최근 실천 기록과 스냅샷 추이를 반영해, "
                "재시작이 필요하면 부드럽게, 목표 조정이 필요하면 완화 제안 위주로 짧게 코칭해 주세요."
            ),
            mode="coach",
            report_ctx=load_report_context(session, db),
            assistant_msg_id=assistant_msg_id,
            send_json=collect,
            db=db,
            snapshot_nudge_mode=True,
        )
        body = "".join(chunks).strip()
        if not body:
            body = (
                "오늘 생활 기록을 확인했어요. "
                "챗봇에서 코치와 이어서 이야기해 보세요."
            )
        row = CoachInAppNudge(user_id=user_id, body=body[:12000])
        db.add(row)
        db.commit()
    except Exception as e:
        print(f"[CoachSnapshotNudge] user={user_id} err={e}")
        db.rollback()
    finally:
        db.close()
