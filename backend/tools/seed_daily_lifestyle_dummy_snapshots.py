#!/usr/bin/env python3
"""
지정 이메일 유저에게 daily_lifestyle_snapshot 더미 데이터를 약 N일치 넣습니다.
기존 (user_id, snapshot_date) 행이 있으면 같은 필드를 더미 값으로 덮어씁니다.

사용 (backend/ 디렉터리, DATABASE_URL 설정):
  python3 tools/seed_daily_lifestyle_dummy_snapshots.py
  python3 tools/seed_daily_lifestyle_dummy_snapshots.py --email user@example.com --days 20

체중·키는 스냅샷 정책상 NULL 로 둡니다.
"""
from __future__ import annotations

import argparse
import math
import os
import sys
from datetime import date, timedelta
from pathlib import Path

# backend/ 를 패키지 루트로
_BACKEND = Path(__file__).resolve().parents[1]
if str(_BACKEND) not in sys.path:
    sys.path.insert(0, str(_BACKEND))

try:
    from dotenv import load_dotenv

    load_dotenv(_BACKEND / ".env")
    load_dotenv(_BACKEND.parent / ".env")
except ImportError:
    pass

from app.database import SessionLocal  # noqa: E402
from app.models import DailyLifestyleSnapshot, User  # noqa: E402

DEFAULT_EMAIL = "qkr789rudfl@sookmyung.ac.kr"

DRINKING_ROT = ("0", "1", "2-3", "1", "0")
UV_ROT = ("<30m", "30~60", "1~2h", ">2h", "30~60")


def _row_for_day(i: int, d: date) -> dict:
    """i: 0..days-1 오래된 날부터 또는 최근부터 — 여기서는 최근일수록 i 큼."""
    phase = i * 0.45
    sleep_minutes = int(420 + 55 * math.sin(phase))  # 약 6~8시간
    sleep_minutes = max(300, min(540, sleep_minutes))
    stress = round(3.5 + 2.8 * (1 + math.sin(phase + 1)) / 2, 1)
    stress = max(1.0, min(10.0, stress))
    sleep_quality = round(5.5 + 2.2 * math.sin(phase - 0.5), 1)
    sleep_quality = max(1.0, min(10.0, sleep_quality))
    aer = (i % 6) + (1 if d.weekday() < 5 else 0)
    aer = min(6, max(0, aer))
    res = (i // 3) % 4
    return {
        "drinking_days_per_week": DRINKING_ROT[i % len(DRINKING_ROT)],
        "smoking_status": "never",
        "stress_score": stress,
        "sleep_minutes": sleep_minutes,
        "sleep_quality_score": sleep_quality,
        "aerobic_sessions_30min": aer,
        "resistance_sessions_30min": res,
        "uv_outdoor_10to16": UV_ROT[i % len(UV_ROT)],
        "sunscreen_applied": (i % 3) != 1,
        "weight_kg": None,
        "height_cm": None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Daily lifestyle snapshot 더미 시드")
    parser.add_argument("--email", default=DEFAULT_EMAIL, help="대상 유저 이메일")
    parser.add_argument("--days", type=int, default=20, help="생성할 일수 (오늘 포함 과거로 채움)")
    args = parser.parse_args()

    if args.days < 1 or args.days > 90:
        print("--days 는 1~90 사이여야 합니다.", file=sys.stderr)
        return 1

    if not os.getenv("DATABASE_URL"):
        print("DATABASE_URL 환경변수가 없습니다. backend/.env 또는 상위 .env 를 확인하세요.", file=sys.stderr)
        return 1

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == args.email).first()
        if not user:
            print(f"유저를 찾을 수 없습니다: {args.email}", file=sys.stderr)
            return 1

        end = date.today()
        inserted = 0
        updated = 0
        for k in range(args.days):
            d = end - timedelta(days=(args.days - 1 - k))
            payload = _row_for_day(k, d)
            row = (
                db.query(DailyLifestyleSnapshot)
                .filter(
                    DailyLifestyleSnapshot.user_id == user.id,
                    DailyLifestyleSnapshot.snapshot_date == d,
                )
                .first()
            )
            if row:
                for key, val in payload.items():
                    setattr(row, key, val)
                updated += 1
            else:
                row = DailyLifestyleSnapshot(
                    user_id=user.id,
                    snapshot_date=d,
                    **payload,
                )
                db.add(row)
                inserted += 1

        db.commit()
        print(
            f"완료: user_id={user.id} ({args.email}) "
            f"스냅샷 {args.days}일 — 신규 {inserted}건, 갱신 {updated}건"
        )
        return 0
    except Exception as e:
        db.rollback()
        print(f"실패: {e}", file=sys.stderr)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
