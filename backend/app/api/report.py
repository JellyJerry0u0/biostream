"""
건강 리포트 생성 API 엔드포인트

Qdrant 중심 RAG + LangGraph 기반 워크플로우를 사용하여 사용자 맞춤형 건강 리포트를 생성합니다.
"""

import sys
import os
from fastapi import APIRouter, Depends, HTTPException, Header, Query, Body
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime
from pydantic import BaseModel
from app.database import get_db
from app.models import User, Lifestyle
from app.auth.security import verify_token

# 신규 LangGraph 기반 리포트 생성 모듈 import
app_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if app_root not in sys.path:
    sys.path.append(app_root)
from report_modules.report_graph import generate_report as generate_report_new

router = APIRouter()


class GenerateReportBody(BaseModel):
    """리포트 생성 시 선택적으로 전달하는 참고 상황 (DB 저장 안 함)"""
    situation_text: Optional[str] = None


def get_current_user(authorization: Optional[str] = Header(None, alias="Authorization"), db: Session = Depends(get_db)):
    """현재 사용자 인증"""
    if not authorization:
        print("[인증] Authorization 헤더가 없습니다.")
        raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")
    
    try:
        token = authorization.replace("Bearer ", "").strip()
        if not token:
            print("[인증] 토큰이 비어있습니다.")
            raise HTTPException(status_code=401, detail="인증 토큰이 필요합니다.")
        
        print(f"[인증] 토큰 검증 시작 (토큰 길이: {len(token)})")
        email = verify_token(token)
        if not email:
            print("[인증] 토큰 검증 실패: 유효하지 않은 토큰")
            raise HTTPException(status_code=401, detail="유효하지 않은 토큰입니다.")
        
        print(f"[인증] 토큰 검증 성공: {email}")
        user = db.query(User).filter(User.email == email).first()
        if not user:
            print(f"[인증] 사용자를 찾을 수 없음: {email}")
            raise HTTPException(status_code=401, detail="사용자를 찾을 수 없습니다.")
        
        print(f"[인증] 인증 성공: user_id={user.id}, email={user.email}")
        return user
    except HTTPException:
        raise
    except Exception as e:
        print(f"[인증] 예상치 못한 오류: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=401, detail=f"인증 실패: {str(e)}")


@router.post("/generate-report/{lifestyle_id}")
def generate_report(
    lifestyle_id: int,
    force: bool = Query(False, description="기존 리포트가 있어도 강제로 재생성"),
    body: Optional[GenerateReportBody] = Body(None),
    authorization: Optional[str] = Header(None, alias="Authorization"),
    db: Session = Depends(get_db)
):
    """
    건강 리포트 생성
    
    LangGraph 워크플로우를 사용하여 설문조사 데이터를 기반으로 
    사용자 맞춤형 건강 리포트를 생성합니다.
    
    Args:
        lifestyle_id: Lifestyle 레코드 ID
        force: True일 경우 기존 리포트가 있어도 강제로 재생성 (기본값: False)
        authorization: JWT 토큰
    
    Returns:
        생성된 리포트 데이터
    """
    # 인증 확인
    current_user = get_current_user(authorization, db)
    
    # Lifestyle 레코드 조회
    lifestyle = db.query(Lifestyle).filter(
        Lifestyle.id == lifestyle_id,
        Lifestyle.user_id == current_user.id
    ).first()
    
    if not lifestyle:
        # 해당 lifestyle_id가 없으면 최신 레코드 조회
        print(f"⚠️ [리포트 생성] lifestyle_id={lifestyle_id}를 찾을 수 없습니다. 최신 레코드를 조회합니다.")
        lifestyle = db.query(Lifestyle).filter(
            Lifestyle.user_id == current_user.id
        ).order_by(Lifestyle.created_at.desc()).first()
        
        if not lifestyle:
            raise HTTPException(
                status_code=404,
                detail="설문조사 데이터를 찾을 수 없습니다."
            )
        print(f"✅ [리포트 생성] 최신 레코드 사용 - lifestyle_id={lifestyle.id}")
        lifestyle_id = lifestyle.id  # 실제 사용할 lifestyle_id 업데이트
    
    # 이미 리포트가 생성되어 있는지 확인 (force=False일 때만)
    if not force and lifestyle.health_report:
        # 리포트 유효성 검사: 신규 리포트 구조 확인
        report_data = lifestyle.health_report
        # 신규 리포트는 final_report 또는 sections 키를 가짐
        has_valid_report = (
            isinstance(report_data, dict) and 
            (report_data.get("final_report") or report_data.get("sections") or report_data.get("report"))
        )
        
        if has_valid_report:
            print(f"[리포트 생성] 이미 생성된 리포트가 있습니다. lifestyle_id: {lifestyle_id}")
            # 기존 클라이언트 호환성을 위해 응답 구조 유지
            return {
                "success": True,
                "message": "이미 생성된 리포트를 반환합니다.",
                "report": lifestyle.health_report,
                "lifestyle_id": lifestyle_id,
                "user_id": current_user.id,
                "generated_at": lifestyle.health_report_generated_at.isoformat() if lifestyle.health_report_generated_at else None,
                "already_exists": True
            }
        else:
            print(f"[리포트 생성] 저장된 리포트가 유효하지 않습니다. 재생성합니다. lifestyle_id: {lifestyle_id}")
            # 유효하지 않은 리포트는 삭제하고 재생성
            lifestyle.health_report = None
            lifestyle.health_report_generated_at = None
            db.commit()
    
    try:
        # 신규 Qdrant 중심 RAG + LangGraph 기반 리포트 생성
        print(f"[리포트 생성] 신규 리포트 생성 시작 - lifestyle_id: {lifestyle_id}, user_id: {current_user.id}")
        
        # 신규 generate_report 호출 (lifestyle_id 지정)
        situation_text = body.situation_text if body and body.situation_text else None
        report_result = generate_report_new(
            user_id=current_user.id,
            lifestyle_id=lifestyle_id,
            situation_text=situation_text,
        )
        
        if not report_result.get("success"):
            raise HTTPException(
                status_code=500,
                detail=f"리포트 생성 실패: {report_result.get('error', '알 수 없는 오류')}"
            )
        
        # 신규 리포트 구조에서 final_report 추출
        new_report = report_result.get("report", {})
        
        # 리포트 저장 (신규 구조 그대로 저장)
        lifestyle.health_report = new_report
        lifestyle.health_report_generated_at = datetime.utcnow()
        db.commit()
        db.refresh(lifestyle)
        
        print(f"[리포트 생성] 리포트 생성 및 저장 완료 - lifestyle_id: {lifestyle_id}")
        
        # 새로운 스키마 (tabs + sections.cards)를 기존 형식으로 변환 (프론트엔드 호환성)
        cards = []
        if isinstance(new_report, dict):
            # 새로운 스키마: tabs + sections 구조
            if new_report.get("tabs") and new_report.get("sections"):
                tabs = new_report.get("tabs", [])
                sections = new_report.get("sections", {})
                
                # 각 섹션의 4개 카드를 하나의 섹션 카드로 변환
                for section_key in tabs:
                    if section_key not in sections:
                        continue
                    
                    section_data = sections[section_key]
                    section_title = section_data.get("title", section_key)
                    section_cards = section_data.get("cards", [])
                    
                    # 4개 카드를 하나의 텍스트로 합치기
                    card_texts = []
                    for card in section_cards:
                        card_type = card.get("type", "")
                        if card_type == "problem":
                            card_texts.append(f"현재 상태: {card.get('text', '')}")
                        elif card_type == "cause":
                            card_texts.append(f"원인: {card.get('text', '')}")
                        elif card_type == "action":
                            items = card.get("items", [])
                            action_text = "\n".join([f"- {item.get('title', '')}: {item.get('detail', '')}" for item in items])
                            card_texts.append(f"행동: {action_text}")
                        elif card_type == "simulation":
                            sim_text = card.get("text", "")
                            meta = card.get("meta", {})
                            if meta.get("mode") == "estimated" and meta.get("disclaimer_small"):
                                sim_text += f"\n({meta['disclaimer_small']})"
                            card_texts.append(f"예상 경로: {sim_text}")
                    
                    section_content = "\n\n".join(card_texts)
                    
                    section_icons = {
                        "goals": "🎯",
                        "sleep": "😴",
                        "uv": "☀️",
                        "lifestyle": "🌱",
                        "activity": "💪",
                    }
                    
                    cards.append({
                        "title": section_title,
                        "icon": section_icons.get(section_key, "📋"),
                        "content": section_content,
                        "has_visualization": False,
                    })
            # 기존 스키마 호환 (sections가 문자열인 경우)
            elif new_report.get("sections"):
                sections = new_report.get("sections", {})
                section_titles = {
                    "goals": {"title": "주요 목표 분석 및 개선 방안", "icon": "🎯"},
                    "sleep": {"title": "수면 및 리듬", "icon": "😴"},
                    "uv": {"title": "자외선 및 노화 관리", "icon": "☀️"},
                    "lifestyle": {"title": "생활습관 관리", "icon": "🌱"},
                    "activity": {"title": "활동 및 대사", "icon": "💪"},
                }
                
                for section_key, section_content in sections.items():
                    section_info = section_titles.get(section_key, {"title": section_key, "icon": "📋"})
                    cards.append({
                        "title": section_info["title"],
                        "icon": section_info["icon"],
                        "content": section_content if isinstance(section_content, str) else str(section_content),
                        "has_visualization": False,
                    })
        
        # 기존 클라이언트 호환성을 위한 응답 구조
        return {
            "success": True,
            "message": "건강 리포트가 성공적으로 생성되었습니다.",
            "report": new_report,
            "cards": cards,
            "lifestyle_id": lifestyle_id,
            "user_id": current_user.id,
            "generated_at": lifestyle.health_report_generated_at.isoformat()
        }
        
    except Exception as e:
        print(f"[오류] 리포트 생성 실패: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"리포트 생성 중 오류가 발생했습니다: {str(e)}"
        )


@router.get("/report/{lifestyle_id}")
def get_report(
    lifestyle_id: int,
    authorization: Optional[str] = Header(None, alias="Authorization"),
    db: Session = Depends(get_db)
):
    """
    생성된 건강 리포트 조회
    
    Args:
        lifestyle_id: Lifestyle 레코드 ID
        authorization: JWT 토큰
    
    Returns:
        저장된 리포트 데이터
    """
    # 인증 확인
    current_user = get_current_user(authorization, db)
    
    # Lifestyle 레코드 조회
    lifestyle = db.query(Lifestyle).filter(
        Lifestyle.id == lifestyle_id,
        Lifestyle.user_id == current_user.id
    ).first()
    
    if not lifestyle:
        raise HTTPException(
            status_code=404,
            detail="해당 설문조사 데이터를 찾을 수 없습니다."
        )
    
    if not lifestyle.health_report:
        raise HTTPException(
            status_code=404,
            detail="생성된 리포트가 없습니다. /generate-report 엔드포인트를 사용하여 리포트를 생성해주세요."
        )
    
    report_data = lifestyle.health_report
    
    # cards가 이미 있으면 그대로 사용
    cards = report_data.get("cards", []) if isinstance(report_data, dict) else []
    
    # cards가 없고 sections가 있으면 sections를 cards로 변환
    if not cards and isinstance(report_data, dict) and report_data.get("sections"):
        sections = report_data.get("sections", {})
        section_titles = {
            "goals": {"title": "주요 목표 분석 및 개선 방안", "icon": "🎯"},
            "sleep": {"title": "수면 및 리듬", "icon": "😴"},
            "uv": {"title": "자외선 및 노화 관리", "icon": "☀️"},
            "lifestyle": {"title": "생활습관 관리", "icon": "🌱"},
            "activity": {"title": "활동 및 대사", "icon": "💪"},
        }
        
        cards = []
        for section_key, section_content in sections.items():
            section_info = section_titles.get(section_key, {"title": section_key, "icon": "📋"})
            cards.append({
                "title": section_info["title"],
                "icon": section_info["icon"],
                "content": section_content if isinstance(section_content, str) else str(section_content),
                "has_visualization": False,
            })
    
    return {
        "success": True,
        "report": lifestyle.health_report,
        "cards": cards,
        "generated_at": lifestyle.health_report_generated_at.isoformat() if lifestyle.health_report_generated_at else None
    }
