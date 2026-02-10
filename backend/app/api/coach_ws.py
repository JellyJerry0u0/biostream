"""
코치 챗봇 WebSocket 엔드포인트

경로: /ws/coach
인증: query param ?token=<jwt> 또는 Authorization 헤더
세션: ?session_id=xxx 또는 첫 메시지에서 수신, 없으면 서버 생성
"""

import uuid
import json
import traceback
from typing import Optional

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query
from sqlalchemy.orm import Session

from app.auth.security import verify_token
from app.database import get_db, SessionLocal
from app.models import User
from app.services.session_store import session_store
from app.services.coach_service import coach_service

router = APIRouter()


async def _authenticate_ws(websocket: WebSocket) -> Optional[User]:
    """
    WebSocket 연결에서 사용자 인증
    1순위: query param ?token=
    2순위: Authorization 헤더
    """
    token = websocket.query_params.get("token")

    if not token:
        auth_header = websocket.headers.get("authorization", "")
        if auth_header.lower().startswith("bearer "):
            token = auth_header[7:].strip()

    if not token:
        return None

    email = verify_token(token)
    if not email:
        return None

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        return user
    finally:
        db.close()


@router.websocket("/ws/coach")
async def coach_websocket(websocket: WebSocket):
    """코치 챗봇 WebSocket 엔드포인트"""

    # ── 인증 ──
    user = await _authenticate_ws(websocket)
    if not user:
        await websocket.close(code=4001, reason="인증 실패")
        return

    await websocket.accept()
    print(f"[WS] 연결 수락: user_id={user.id}, email={user.email}")

    # ── 세션 초기화 ──
    session_id = websocket.query_params.get("session_id")
    report_id_str = websocket.query_params.get("report_id")
    report_id = int(report_id_str) if report_id_str else None

    session = session_store.get_or_create(
        session_id=session_id,
        user_id=user.id,
        report_id=report_id,
    )

    # send_json 헬퍼
    async def send_json(data: dict):
        try:
            await websocket.send_json(data)
        except Exception as e:
            print(f"[WS] 전송 실패: {e}")

    try:
        while True:
            # ── 메시지 수신 ──
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                await send_json({"type": "error", "message": "잘못된 JSON 형식"})
                continue

            msg_type = data.get("type", "user_message")

            # 세션 ID 업데이트 (첫 메시지에서 올 수 있음)
            if data.get("session_id") and not session_id:
                # 첫 메시지에서 session_id를 받은 경우
                old_session = session
                session = session_store.get_or_create(
                    session_id=data["session_id"],
                    user_id=user.id,
                    report_id=session.report_id,
                )
                # 기존 세션 데이터 이관
                if old_session.session_id != session.session_id:
                    session.history = old_session.history
                    session.coach_memory_dict = old_session.coach_memory_dict

            # report_id 업데이트
            if data.get("report_id"):
                session.report_id = int(data["report_id"])

            # ── mode_switch 처리 (DB 불필요) ──
            if msg_type == "mode_switch":
                new_engine = data.get("engine", "quick")
                if new_engine not in ("quick", "deep"):
                    await send_json({"type": "error", "message": f"잘못된 엔진: {new_engine}"})
                    continue

                session.engine = new_engine
                label = "일반 코치" if new_engine == "quick" else "심화 코치"
                await send_json({
                    "type": "mode_info",
                    "engine": new_engine,
                    "label": label,
                })
                print(f"[WS] 모드 전환: {new_engine} (user_id={user.id})")
                continue

            # 어시스턴트 메시지 ID 생성
            assistant_msg_id = str(uuid.uuid4())

            # ── DB 세션 (읽기 전용) ──
            db = SessionLocal()

            try:
                if msg_type == "user_message":
                    message = data.get("message", "").strip()
                    if not message:
                        await send_json({"type": "error", "message": "메시지가 비어있습니다."})
                        continue

                    mode = data.get("mode", "auto")
                    engine_override = data.get("engine")  # 메시지 단위 오버라이드

                    # start 이벤트 전송
                    await send_json({
                        "type": "start",
                        "session_id": session.session_id,
                        "assistant_message_id": assistant_msg_id,
                    })

                    # 코치 서비스에 위임
                    await coach_service.handle_user_message(
                        session=session,
                        user_message=message,
                        mode=mode,
                        assistant_msg_id=assistant_msg_id,
                        send_json=send_json,
                        db=db,
                        engine_override=engine_override,
                    )

                elif msg_type == "action":
                    action_id = data.get("action_id", "")
                    payload = data.get("payload", {})

                    # start 이벤트 전송
                    await send_json({
                        "type": "start",
                        "session_id": session.session_id,
                        "assistant_message_id": assistant_msg_id,
                    })

                    await coach_service.handle_action_event(
                        session=session,
                        action_id=action_id,
                        payload=payload,
                        assistant_msg_id=assistant_msg_id,
                        send_json=send_json,
                        db=db,
                    )

                else:
                    await send_json({
                        "type": "error",
                        "message": f"알 수 없는 메시지 타입: {msg_type}",
                    })

            finally:
                db.close()

    except WebSocketDisconnect:
        print(f"[WS] 연결 끊김: user_id={user.id}, session={session.session_id}")
    except Exception as e:
        print(f"[WS] 예외 발생: {e}")
        traceback.print_exc()
        try:
            await send_json({"type": "error", "message": f"서버 오류: {str(e)[:100]}"})
        except Exception:
            pass
