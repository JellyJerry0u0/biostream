#!/usr/bin/env python3
"""
코치 챗봇 WebSocket 테스트 클라이언트

사용법:
  1) 서버 실행: uvicorn app.main:app --host 0.0.0.0 --port 8080
  2) 이 스크립트 실행: python test_ws_client.py

환경변수:
  - TEST_TOKEN: JWT 토큰 (없으면 자동 로그인 시도)
  - API_BASE: 서버 주소 (기본: http://localhost:8080)
"""

import os
import sys
import json
import asyncio

# websockets 패키지 필요: pip install websockets
try:
    import websockets
except ImportError:
    print("websockets 패키지를 설치하세요: pip install websockets")
    sys.exit(1)

try:
    import httpx
except ImportError:
    httpx = None

API_BASE = os.getenv("API_BASE", "http://localhost:8080")
WS_BASE = API_BASE.replace("https://", "wss://").replace("http://", "ws://")


async def get_token() -> str:
    """환경변수에서 토큰을 읽거나, 로그인하여 토큰 획득"""
    token = os.getenv("TEST_TOKEN")
    if token:
        return token

    if not httpx:
        print("httpx가 없어 자동 로그인 불가. TEST_TOKEN 환경변수를 설정하세요.")
        sys.exit(1)

    # 테스트 계정으로 로그인 시도
    print("[로그인] 테스트 계정으로 로그인 시도...")
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{API_BASE}/auth/login",
            json={"email": "test@test.com", "password": "test1234"},
        )
        if resp.status_code == 200:
            data = resp.json()
            token = data["access_token"]
            print(f"[로그인] 성공: nickname={data.get('nickname')}")
            return token
        else:
            print(f"[로그인] 실패: {resp.status_code} {resp.text}")
            print("TEST_TOKEN 환경변수를 설정하거나, 테스트 계정(test@test.com / test1234)을 생성하세요.")
            sys.exit(1)


async def main():
    token = await get_token()
    ws_url = f"{WS_BASE}/ws/coach?token={token}"

    print(f"\n[연결] {ws_url}")
    async with websockets.connect(ws_url) as ws:
        print("[연결] WebSocket 연결 성공!\n")
        print("=" * 50)
        print("코치 챗봇 테스트 클라이언트")
        print("메시지를 입력하세요 (빈 줄 = 종료, /action <id> = 액션)")
        print("=" * 50)

        # 수신 태스크
        async def receiver():
            try:
                async for raw in ws:
                    data = json.loads(raw)
                    msg_type = data.get("type")

                    if msg_type == "start":
                        print(f"\n[START] session={data.get('session_id')}, msg_id={data.get('assistant_message_id')[:8]}...")

                    elif msg_type == "delta":
                        # 스트리밍 텍스트 — 줄바꿈 없이 이어서 출력
                        print(data.get("delta", ""), end="", flush=True)

                    elif msg_type == "actions":
                        items = data.get("items", [])
                        print(f"\n\n[ACTIONS] {len(items)}개:")
                        for item in items:
                            print(f"  - [{item['id']}] {item['label']}")

                    elif msg_type == "citations":
                        items = data.get("items", [])
                        print(f"\n[CITATIONS] {len(items)}개:")
                        for item in items:
                            print(f"  - {item.get('paper_id', '?')} / {item.get('source_section', '')}")

                    elif msg_type == "memory_update":
                        items = data.get("items", [])
                        print(f"\n[MEMORY] 업데이트: {items}")

                    elif msg_type == "done":
                        print(f"\n[DONE]\n{'─' * 40}")

                    elif msg_type == "error":
                        print(f"\n[ERROR] {data.get('message')}")

                    else:
                        print(f"\n[???] {data}")

            except websockets.exceptions.ConnectionClosed:
                print("\n[연결 종료]")

        # 수신 태스크 시작
        recv_task = asyncio.create_task(receiver())

        # 송신 루프
        try:
            while True:
                user_input = await asyncio.get_event_loop().run_in_executor(
                    None, input, "\n[YOU] > "
                )

                if not user_input.strip():
                    print("[종료]")
                    break

                # /action 명령어
                if user_input.startswith("/action "):
                    action_id = user_input[8:].strip()
                    msg = {
                        "type": "action",
                        "action_id": action_id,
                        "payload": {},
                    }
                    await ws.send(json.dumps(msg))
                    print(f"[ACTION 전송] {action_id}")
                    continue

                # /report <id> 명령어
                if user_input.startswith("/report "):
                    report_id = user_input[8:].strip()
                    msg = {
                        "type": "user_message",
                        "message": "내 리포트 결과를 설명해줘",
                        "report_id": int(report_id),
                        "mode": "report_explain",
                    }
                    await ws.send(json.dumps(msg))
                    print(f"[리포트 모드] report_id={report_id}")
                    continue

                # 일반 메시지
                msg = {
                    "type": "user_message",
                    "message": user_input,
                    "mode": "auto",
                }
                await ws.send(json.dumps(msg))

        except (KeyboardInterrupt, EOFError):
            print("\n[종료]")

        recv_task.cancel()


if __name__ == "__main__":
    asyncio.run(main())
