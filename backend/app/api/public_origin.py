"""응답 JSON에 넣는 절대 URL용 API 오리진."""

import os
from typing import Optional

from starlette.requests import Request


def _is_loopback_origin(origin: str) -> bool:
    o = origin.lower()
    return "localhost" in o or "127.0.0.1" in o


def resolve_public_api_origin(request: Optional[Request]) -> str:
    """
    우선순위:
    1) API_BASE_ORIGIN 이 비어 있지 않고, localhost 가 아니면 그대로 사용 (프로덕션·고정 주소)
    2) API_BASE_ORIGIN 이 localhost 인데, 클라이언트가 LAN IP 등으로 요청한 경우 → 요청 Host 사용
       (앱 온보딩 개발자 설정과 맞추기 위함)
    3) 그 외 현재 HTTP 요청의 base URL
    4) API_BASE_ORIGIN 또는 http://localhost:8080
    """
    env = (os.getenv("API_BASE_ORIGIN") or "").strip()
    req_origin = str(request.base_url).rstrip("/") if request is not None else ""

    if env:
        if request is not None and _is_loopback_origin(env):
            host = (request.url.hostname or "").lower()
            if host and not _is_loopback_origin(host):
                return req_origin
        return env.rstrip("/")

    if req_origin:
        return req_origin
    return "http://localhost:8080"
