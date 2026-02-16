"""
리포트 저장 도구
생성된 리포트를 데이터베이스에 저장합니다.
"""

from typing import Dict, Any, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Lifestyle


def save_report(
    user_id: int, 
    report: Dict[str, Any], 
    lifestyle_id: Optional[int] = None, 
    db: Optional[Session] = None,
    # 이미지 생성 관련 인자
    generated_image_url: Optional[str] = None,
    generation_status: Optional[str] = None,
    image_gen_params: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    리포트를 데이터베이스에 저장합니다.
    
    Args:
        user_id: 사용자 ID
        report: 리포트 데이터 딕셔너리
        lifestyle_id: Lifestyle 레코드 ID (None이면 최신 레코드 사용)
        db: 데이터베이스 세션 (None이면 자동으로 생성)
        generated_image_url: AI가 생성한 미래 얼굴 이미지 URL
        generation_status: 이미지 생성 상태
        image_gen_params: 이미지 생성에 사용된 파라미터
    
    Returns:
        저장 결과 (report_id, timestamp, generated_image_url 포함)
    """
    # TODO: 현재는 Lifestyle 레코드의 health_report 필드에 저장합니다.
    # 향후 별도 Report 테이블이 필요하면 여기에 추가하세요.
    
    if db is None:
        # 세션이 제공되지 않으면 생성
        db_gen = get_db()
        db = next(db_gen)
        should_close = True
    else:
        should_close = False
    
    try:
        # Lifestyle 레코드 조회
        if lifestyle_id:
            lifestyle = db.query(Lifestyle).filter(
                Lifestyle.id == lifestyle_id,
                Lifestyle.user_id == user_id
            ).first()
        else:
            # 최신 레코드 조회
            lifestyle = db.query(Lifestyle).filter(
                Lifestyle.user_id == user_id
            ).order_by(Lifestyle.created_at.desc()).first()
        
        if not lifestyle:
            return {
                "error": "Lifestyle 레코드를 찾을 수 없습니다.",
                "user_id": user_id
            }
        
        # 리포트 저장
        lifestyle.health_report = report
        lifestyle.health_report_generated_at = datetime.utcnow()
        
        # ⭐ 이미지 관련 데이터 저장 (바구니에서 꺼내 DB 선반에 올리기)
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
            "report_id": str(lifestyle.id),  # lifestyle_id를 report_id로 사용
            "timestamp": lifestyle.health_report_generated_at.isoformat(),
            "lifestyle_id": lifestyle.id,
            "generated_image_url": lifestyle.generated_image_url  # 확인용 반환
        }
        
    except Exception as e:
        if should_close:
            db.rollback()
        return {
            "error": f"리포트 저장 실패: {str(e)}",
            "user_id": user_id
        }
    finally:
        if should_close:
            db.close()