"""
리포트 생성 파이프라인 (순차 호출)
- generate_report: 리포트 생성 메인 함수
- LangGraph 제거, Plain Python 순차 호출로 단순화
"""

from typing import Dict, Any, Optional

from .report_constants import ReportState
from .report_graph import (
    load_survey,
    plan_sections,
    derive_user_profile,
    preload_quant_evidence,
    build_queries,
    retrieve_narrative_evidence,
    extract_claims,
    write_section_cards,
    validate_cards,
    assemble_report,
    generate_aging_image_node,
    save_report_node,
    export_to_notion_node,
)


def _should_retry(state: dict) -> bool:
    """validate_cards 후 재시도 필요 여부"""
    if not state.get("retry_needed") or not state.get("retry_sections"):
        return False
    rc = state.get("retry_count", {}).get("validate_cards", {})
    for sec in state.get("retry_sections", []):
        if rc.get(sec, 0) <= 1:
            return True
    return False


def run_report_pipeline(
    user_id: int,
    lifestyle_id: Optional[int] = None,
    situation_text: Optional[str] = None,
    persist_report: bool = True,
    skip_image: bool = False,
) -> Dict[str, Any]:
    """파이프라인 실행 후 최종 state 반환 (테스트/RAGAS용)

    skip_image: True면 이미지 생성 생략 (약 5~30초 단축)
    """
    state: ReportState = {
        "user_id": user_id,
        "lifestyle_id": lifestyle_id,
        "survey": None,
        "user_profile": None,
        "active_sections": [],
        "available_quant_outcomes": None,
        "quant_evidence_results": {},
        "section_queries": {},
        "narrative_evidence": {},
        "extracted_claims": {},
        "section_cards": {},
        "quality_flags": {},
        "final_report": None,
        "situation_text": situation_text,
        "persist_report": persist_report,
    }
    if situation_text:
        print(f"[ReportGraph] initial_state에 situation_text 반영: {situation_text[:50]}...")

    state = load_survey(state)  # Lifestyle 설문만 (스냅샷·HealthData 미병합)
    state = plan_sections(state)
    state = derive_user_profile(state)
    state = preload_quant_evidence(state)
    state = build_queries(state)
    state = retrieve_narrative_evidence(state)
    state = extract_claims(state)

    for _ in range(3):
        state = write_section_cards(state)
        state = validate_cards(state)
        if not _should_retry(state):
            break

    state = assemble_report(state)
    if not skip_image:
        state = generate_aging_image_node(state)
    else:
        state = {**state, "generated_image_url": None, "generation_status": "skipped"}
    state = save_report_node(state)
    state = export_to_notion_node(state)
    return state


def generate_report(
    user_id: int,
    lifestyle_id: Optional[int] = None,
    situation_text: Optional[str] = None,
    persist_report: bool = True,
    skip_image: bool = False,
) -> Dict[str, Any]:
    """리포트 생성 메인 함수 (순차 파이프라인)

    skip_image: True면 이미지 생성 생략 (응답 속도 향상)
    """
    try:
        state = run_report_pipeline(
            user_id=user_id,
            lifestyle_id=lifestyle_id,
            situation_text=situation_text,
            persist_report=persist_report,
            skip_image=skip_image,
        )
        final_report = state.get("final_report")
        if final_report:
            return {"success": True, "report": final_report}

        return {"success": False, "error": "리포트 생성 실패"}
    except Exception as e:
        print(f"[오류] 리포트 생성 실패: {str(e)}")
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}
