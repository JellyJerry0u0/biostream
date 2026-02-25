from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.auth.security import verify_token
from app.database import get_db
from app.models import User, UserDeviceToken
from app.services.push_service import send_push_to_user

router = APIRouter(prefix="/api/fcm", tags=["FCM Notification"])


class DeviceTokenRequest(BaseModel):
    token: str = Field(min_length=10)
    platform: str = Field(default="android")


class TestPushRequest(BaseModel):
    title: str = Field(default="ChronoLens 알림")
    body: str = Field(default="새로운 분석 리포트가 준비되었습니다.")


def _get_user_from_auth(authorization: Optional[str], db: Session) -> User:
    if not authorization:
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")

    token = authorization.replace("Bearer ", "")
    email = verify_token(token)
    if not email:
        raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return user


@router.post("/token")
def register_device_token(
    payload: DeviceTokenRequest,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    user = _get_user_from_auth(authorization, db)

    token_row = (
        db.query(UserDeviceToken)
        .filter(
            UserDeviceToken.user_id == user.id,
            UserDeviceToken.device_token == payload.token,
        )
        .first()
    )

    if token_row:
        token_row.platform = payload.platform
    else:
        db.add(
            UserDeviceToken(
                user_id=user.id,
                device_token=payload.token,
                platform=payload.platform,
            )
        )

    db.commit()
    return {"success": True, "message": "FCM 토큰 등록 완료"}


@router.delete("/token")
def unregister_device_token(
    payload: DeviceTokenRequest,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    user = _get_user_from_auth(authorization, db)

    deleted = (
        db.query(UserDeviceToken)
        .filter(
            UserDeviceToken.user_id == user.id,
            UserDeviceToken.device_token == payload.token,
        )
        .delete()
    )

    db.commit()
    return {"success": True, "deleted": deleted}


@router.post("/test")
def send_test_push(
    payload: TestPushRequest,
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db),
):
    user = _get_user_from_auth(authorization, db)

    ok = send_push_to_user(
        db=db,
        user_id=user.id,
        title=payload.title,
        body=payload.body,
        data={"type": "test"},
    )

    if not ok:
        return {
            "success": False,
            "message": "푸시 발송 실패 (FCM_SERVER_KEY 또는 등록 토큰 확인 필요)",
        }

    return {"success": True, "message": "테스트 푸시 발송 완료"}
