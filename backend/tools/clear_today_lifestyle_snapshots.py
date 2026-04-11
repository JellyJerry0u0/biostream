#!/usr/bin/env python3
"""
daily_lifestyle_snapshot 중 지정한 날짜 행을 삭제합니다.

기본 삭제일은 Asia/Seoul 달력 '오늘'입니다. (앱이 저장하는 snapshot_date·도커 UTC와 맞춤)
로컬 PC 타임존·date.today()만 쓰면 한국에서 하루 어긋날 수 있습니다.

  python3 tools/clear_today_lifestyle_snapshots.py --email you@mail.com
  python3 tools/clear_today_lifestyle_snapshots.py --email you@mail.com --date 2026-03-27
  python3 tools/clear_today_lifestyle_snapshots.py --all-users
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

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
_KST = ZoneInfo("Asia/Seoul")


def _korea_today() -> date:
    return datetime.now(_KST).date()


def main() -> int:
    parser = argparse.ArgumentParser(description="일별 생활 스냅샷 삭제 (기본 날짜: 한국 달력 오늘)")
    parser.add_argument(
        "--email",
        default=DEFAULT_EMAIL,
        help="해당 유저만 (기본: 숙대 테스트 계정). --all-users 와 함께 쓰지 마세요.",
    )
    parser.add_argument(
        "--all-users",
        action="store_true",
        help="지정 날짜 스냅샷을 모든 유저에서 삭제",
    )
    parser.add_argument(
        "--date",
        default=None,
        metavar="YYYY-MM-DD",
        help="삭제할 snapshot_date (생략 시 Asia/Seoul 기준 오늘)",
    )
    args = parser.parse_args()

    if not os.getenv("DATABASE_URL"):
        print("DATABASE_URL 이 없습니다.", file=sys.stderr)
        return 1

    if args.date:
        try:
            target = date.fromisoformat(args.date)
        except ValueError:
            print("--date 는 YYYY-MM-DD 형식이어야 합니다.", file=sys.stderr)
            return 1
    else:
        target = _korea_today()
    db = SessionLocal()
    try:
        q = db.query(DailyLifestyleSnapshot).filter(
            DailyLifestyleSnapshot.snapshot_date == target
        )
        if not args.all_users:
            user = db.query(User).filter(User.email == args.email).first()
            if not user:
                print(f"유저 없음: {args.email}", file=sys.stderr)
                return 1
            q = q.filter(DailyLifestyleSnapshot.user_id == user.id)
            scope = f"user_id={user.id} ({args.email})"
        else:
            scope = "전체 유저"

        rows = q.all()
        n = len(rows)
        for r in rows:
            db.delete(r)
        db.commit()
        print(f"삭제 완료: {target.isoformat()} · {scope} · {n}건")
        return 0
    except Exception as e:
        db.rollback()
        print(f"실패: {e}", file=sys.stderr)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
