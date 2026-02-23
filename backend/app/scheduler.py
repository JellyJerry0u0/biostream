from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import HealthData
from report_modules.report_graph import generate_report

_scheduler: BackgroundScheduler | None = None


def run_daily_analysis() -> None:
    """매일 01:00에 실행: 미처리 건강데이터 기반 리포트 생성"""
    db: Session = SessionLocal()
    try:
        unprocessed_list = db.query(HealthData).filter(HealthData.is_processed.is_(False)).all()
        print(f"📊 [ChronoLens] 분석 시작: {len(unprocessed_list)}명의 새로운 데이터 감지")

        for entry in unprocessed_list:
            try:
                result = generate_report(user_id=entry.user_id)

                if result.get("success"):
                    entry.is_processed = True
                    db.commit()
                    print(f"✅ User {entry.user_id} 리포트 생성 완료")
                else:
                    db.rollback()
                    print(f"⚠️ User {entry.user_id} 분석 실패: {result.get('error')}")
            except Exception as e:
                db.rollback()
                print(f"❌ User {entry.user_id} 분석 중 치명적 오류: {e}")
    finally:
        db.close()


def start_scheduler() -> None:
    global _scheduler

    if _scheduler is not None and _scheduler.running:
        return

    _scheduler = BackgroundScheduler(timezone="Asia/Seoul")
    _scheduler.add_job(
        run_daily_analysis,
        trigger=CronTrigger(hour=1, minute=0),
        id="daily_analysis_job",
        replace_existing=True,
        misfire_grace_time=3600,
        coalesce=True,
    )
    _scheduler.start()
    print("🚀 [ChronoLens] 분석 스케줄러 가동 시작 (01:00 AM)")


def stop_scheduler() -> None:
    global _scheduler

    if _scheduler is None:
        return

    if _scheduler.running:
        _scheduler.shutdown(wait=False)

    _scheduler = None
