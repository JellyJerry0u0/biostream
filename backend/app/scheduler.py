from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import HealthData
from report_modules.report_graph import generate_report
from app.services.push_service import send_push_to_user

_scheduler: BackgroundScheduler | None = None


def run_daily_analysis() -> None:
    """매일 01:00에 실행: 미처리 건강데이터 기반 리포트 생성"""
    db: Session = SessionLocal()
    try:
        unprocessed_list = db.query(HealthData).filter(HealthData.is_processed.is_(False)).all()
        print(f"📊 [ChronoLens] 분석 시작: {len(unprocessed_list)}명의 새로운 데이터 감지")

        for entry in unprocessed_list:
            try:
                #리포트 생성 함수 호출(LangGraph 워크플로우 실행)
                result = generate_report(user_id=entry.user_id)

                if result.get("success"):
                    entry.is_processed = True
                    sent_now = send_push_to_user(
                        db=db,
                        user_id=entry.user_id,
                        title="리포트 도착",
                        body="오늘의 건강 분석 리포트가 준비되었습니다.",
                        data={"type": "report_ready", "sync_date": str(entry.sync_date)},
                    )
                    entry.notification_sent = sent_now
                    db.commit()
                    if sent_now:
                        print(f"✅ User {entry.user_id} 리포트 생성 + 즉시 푸시 발송 완료")
                    else:
                        print(f"⚠️ User {entry.user_id} 리포트 생성 완료 (즉시 푸시 실패, 07:00 재시도)")
                else:
                    db.rollback()
                    print(f"⚠️ User {entry.user_id} 분석 실패: {result.get('error')}")
            except Exception as e:
                db.rollback()
                print(f"❌ User {entry.user_id} 분석 중 치명적 오류: {e}")
    finally:
        db.close()


def run_morning_push() -> None:
    """매일 07:00에 실행: 생성 완료 + 미발송 사용자에게 푸시 발송"""
    db: Session = SessionLocal()
    try:
        target_list = db.query(HealthData).filter(
            HealthData.is_processed.is_(True),
            HealthData.notification_sent.is_(False)
        ).all()
        print(f"🔔 [ChronoLens] 아침 푸시 시작: {len(target_list)}건")

        for entry in target_list:
            try:
                sent = send_push_to_user(
                    db=db,
                    user_id=entry.user_id,
                    title="리포트 도착",
                    body="오늘의 건강 분석 리포트가 준비되었습니다.",
                    data={"type": "daily_report", "sync_date": str(entry.sync_date)},
                )
                if sent:
                    entry.notification_sent = True
                    db.commit()
                    print(f"✅ User {entry.user_id} 아침 푸시 발송 완료")
                else:
                    db.rollback()
                    print(f"⚠️ User {entry.user_id} 아침 푸시 발송 실패")
            except Exception as e:
                db.rollback()
                print(f"❌ User {entry.user_id} 아침 푸시 중 치명적 오류: {e}")
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
    _scheduler.add_job(
        run_morning_push,
        trigger=CronTrigger(hour=7, minute=0),
        id="morning_push_job",
        replace_existing=True,
        misfire_grace_time=3600,
        coalesce=True,
    )
    _scheduler.start()
    print("🚀 [ChronoLens] 스케줄러 가동 시작 (분석 01:00 / 푸시 07:00)")


def stop_scheduler() -> None:
    global _scheduler

    if _scheduler is None:
        return

    if _scheduler.running:
        _scheduler.shutdown(wait=False)

    _scheduler = None
