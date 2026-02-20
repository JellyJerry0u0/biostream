import os
from typing import Any, Dict

import httpx
from sqlalchemy.orm import Session

from app.models import UserDeviceToken


def send_push_to_user(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    data: Dict[str, Any] | None = None,
) -> bool:
    server_key = os.getenv("FCM_SERVER_KEY", "").strip()
    if not server_key:
        return False

    tokens = (
        db.query(UserDeviceToken)
        .filter(UserDeviceToken.user_id == user_id)
        .all()
    )
    if not tokens:
        return False

    headers = {
        "Authorization": f"key={server_key}",
        "Content-Type": "application/json",
    }

    success = False
    payload_data = {k: str(v) for k, v in (data or {}).items()}

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
