import os
from typing import Any, Dict

import httpx
from sqlalchemy.orm import Session
from firebase_admin import credentials, initialize_app, messaging
import firebase_admin

from app.models import UserDeviceToken


def _send_with_legacy_key(
    tokens: list[UserDeviceToken],
    server_key: str,
    title: str,
    body: str,
    payload_data: Dict[str, str],
) -> bool:
    headers = {
        "Authorization": f"key={server_key}",
        "Content-Type": "application/json",
    }

    success = False
    for token_row in tokens:
        payload = {
            "to": token_row.device_token,
            "priority": "high",
            "notification": {
                "title": title,
                "body": body,
            },
            "data": payload_data,
        }

        try:
            response = httpx.post(
                "https://fcm.googleapis.com/fcm/send",
                headers=headers,
                json=payload,
                timeout=8.0,
            )
            if response.status_code == 200:
                success = True
        except Exception:
            continue

    return success


def _ensure_firebase_admin_initialized() -> bool:
    if firebase_admin._apps:
        return True

    service_account_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    try:
        if service_account_path:
            cred = credentials.Certificate(service_account_path)
            initialize_app(cred)
        else:
            initialize_app()
        return True
    except Exception as e:
        print(f"⚠️ [FCM] Firebase Admin 초기화 실패: {e}")
        return False


def _send_with_firebase_admin(
    tokens: list[UserDeviceToken],
    title: str,
    body: str,
    payload_data: Dict[str, str],
) -> bool:
    if not _ensure_firebase_admin_initialized():
        return False

    token_values = [row.device_token for row in tokens if row.device_token]
    if not token_values:
        return False

    message = messaging.MulticastMessage(
        tokens=token_values,
        notification=messaging.Notification(title=title, body=body),
        data=payload_data,
        android=messaging.AndroidConfig(priority="high"),
    )

    try:
        response = messaging.send_each_for_multicast(message)
        print(f"ℹ️ [FCM] Firebase Admin 발송 결과: success={response.success_count}, failure={response.failure_count}")
        return response.success_count > 0
    except Exception as e:
        print(f"⚠️ [FCM] Firebase Admin 발송 실패: {e}")
        return False


def send_push_to_user(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    data: Dict[str, Any] | None = None,
) -> bool:
    tokens = (
        db.query(UserDeviceToken)
        .filter(UserDeviceToken.user_id == user_id)
        .all()
    )
    if not tokens:
        print(f"ℹ️ [FCM] user_id={user_id} 등록 토큰 없음")
        return False

    payload_data = {k: str(v) for k, v in (data or {}).items()}

    server_key = os.getenv("FCM_SERVER_KEY", "").strip()
    if server_key:
        return _send_with_legacy_key(tokens, server_key, title, body, payload_data)

    print("ℹ️ [FCM] FCM_SERVER_KEY 없음, Firebase Admin 방식으로 발송 시도")
    return _send_with_firebase_admin(tokens, title, body, payload_data)
