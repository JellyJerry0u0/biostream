"""
리포트 저장 도구
생성된 리포트를 데이터베이스에 저장합니다.
health_reports 테이블에 저장하며, Lifestyle에는 generated_image_url 등 denormalized 필드를 유지합니다.
"""

from typing import Dict, Any, Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Lifestyle, Report


def save_report(
    user_id: int,
    report: Dict[str, Any],
    lifestyle_id: Optional[int] = None,
    db: Optional[Session] = None,
    # 이미지 생성 관련 인자
    generated_image_url: Optional[str] = None,
    generation_status: Optional[str] = None,
    image_gen_params: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    리포트를 health_reports 테이블에 저장합니다.
    Lifestyle의 generated_image_url, generation_status, image_gen_params도 함께 업데이트합니다.

    Args:
        user_id: 사용자 ID
        report: 리포트 데이터 딕셔너리
        lifestyle_id: Lifestyle 레코드 ID (None이면 저장 중단)
        db: 데이터베이스 세션 (None이면 자동으로 생성)
        generated_image_url: AI가 생성한 미래 얼굴 이미지 URL
        generation_status: 이미지 생성 상태
        image_gen_params: 이미지 생성에 사용된 파라미터

    Returns:
        저장 결과 (report_id, timestamp, generated_image_url 포함)
    """
    if db is None:
        db_gen = get_db()
        db = next(db_gen)
        should_close = True
    else:
        should_close = False

    try:
        if not lifestyle_id:
            return {
                "error": "lifestyle_id가 없어 리포트 저장을 중단합니다.",
                "user_id": user_id,
            }

        lifestyle = db.query(Lifestyle).filter(
            Lifestyle.id == lifestyle_id,
            Lifestyle.user_id == user_id,
        ).first()

        if not lifestyle:
            return {
                "error": "Lifestyle 레코드를 찾을 수 없습니다.",
                "user_id": user_id,
            }

        generated_at = datetime.now(timezone.utc)

        # health_reports에 저장 (upsert: 기존 리포트가 있으면 업데이트)
        existing = db.query(Report).filter(Report.lifestyle_id == lifestyle_id).first()
        if existing:
            existing.report = report
            existing.generated_at = generated_at
            db.add(existing)
            report_id = str(existing.id)
        else:
            new_report = Report(
                lifestyle_id=lifestyle_id,
                report=report,
                generated_at=generated_at,
            )
            db.add(new_report)
            db.flush()
            report_id = str(new_report.id)

        # Lifestyle denormalized 필드 업데이트 (이미지 서빙 등에서 사용)
        if generated_image_url:
            lifestyle.generated_image_url = generated_image_url
        if generation_status:
            lifestyle.generation_status = generation_status
        if image_gen_params:
            lifestyle.image_gen_params = image_gen_params

        db.commit()
        db.refresh(lifestyle)

        return {
            "success": True,
            "report_id": report_id,
            "timestamp": generated_at.isoformat(),
            "lifestyle_id": lifestyle.id,
            "generated_image_url": lifestyle.generated_image_url,
        }

    except Exception as e:
        if should_close:
            db.rollback()
        return {
            "error": f"리포트 저장 실패: {str(e)}",
            "user_id": user_id,
        }
    finally:
        if should_close:
            db.close()