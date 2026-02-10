#MCP 서버 메인 실행 파일(Gemini와 통신하는 입구)
# mcp/server.py 예시
import sys
import os
from pathlib import Path

# 컨테이너 환경에서 올바른 경로 설정
# /app이 WORKDIR이고 PYTHONPATH=/app이므로 mcp_server 모듈을 찾을 수 있어야 함
mcp_server_dir = Path(__file__).parent.absolute()
app_dir = mcp_server_dir.parent.absolute()

# PYTHONPATH에 /app 추가 (이미 설정되어 있어야 하지만 안전하게)
if str(app_dir) not in sys.path:
    sys.path.insert(0, str(app_dir))

# 현재 디렉토리도 경로에 추가 (상대 import를 위한 fallback)
if str(mcp_server_dir) not in sys.path:
    sys.path.insert(0, str(mcp_server_dir))

from mcp.server.fastmcp import FastMCP

# tools 모듈 직접 import (경로 문제 해결)
# 방법 1: 절대 경로 import
try:
    from mcp_server.tools.db_tools import fetch_user_aging_context
except ImportError:
    # 방법 2: 직접 경로에서 import
    try:
        import importlib.util
        tools_path = mcp_server_dir / "tools" / "db_tools.py"
        spec = importlib.util.spec_from_file_location("db_tools", tools_path)
        db_tools = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(db_tools)
        fetch_user_aging_context = db_tools.fetch_user_aging_context
    except Exception as e:
        raise ImportError(f"Could not import fetch_user_aging_context: {e}")

mcp = FastMCP("BioStream")

# 도구 등록
@mcp.tool()
async def get_user_health_report(user_id: int):
    """유저의 최신 건강 데이터를 카테고리별로 가져와 노화 분석 맥락을 제공합니다."""
    return fetch_user_aging_context(user_id)

# 검증 도구 import
try:
    from mcp_server.tools.validation_tools import validate_section_structure
except ImportError:
    try:
        import importlib.util
        validation_path = mcp_server_dir / "tools" / "validation_tools.py"
        spec = importlib.util.spec_from_file_location("validation_tools", validation_path)
        validation_tools = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(validation_tools)
        validate_section_structure = validation_tools.validate_section_structure
    except Exception as e:
        raise ImportError(f"Could not import validate_section_structure: {e}")

@mcp.tool()
async def validate_report_section(section_content: str, section_type: str):
    """
    리포트 섹션이 구조화된 형식인지 검증합니다.
    
    Args:
        section_content: 검증할 섹션 내용
        section_type: 섹션 타입 (goals, sleep, uv, lifestyle, activity)
    
    Returns:
        검증 결과 딕셔너리
    """
    return validate_section_structure(section_content, section_type)

# 시각자료 도구 import
try:
    from mcp_server.tools.visualization_tools import generate_visualization
except ImportError:
    try:
        import importlib.util
        viz_path = mcp_server_dir / "tools" / "visualization_tools.py"
        spec = importlib.util.spec_from_file_location("visualization_tools", viz_path)
        viz_tools = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(viz_tools)
        generate_visualization = viz_tools.generate_visualization
    except Exception as e:
        raise ImportError(f"Could not import generate_visualization: {e}")

@mcp.tool()
async def create_section_visualization(section_type: str, section_content: str, lifestyle_data: dict):
    """
    리포트 섹션에 대한 시각자료(차트/표)를 생성합니다.
    
    Args:
        section_type: 섹션 타입 (goals, sleep, uv, lifestyle, activity)
        section_content: 섹션 내용
        lifestyle_data: 사용자 생활습관 데이터 (딕셔너리)
    
    Returns:
        시각자료 정보 (base64 인코딩된 이미지)
    """
    return generate_visualization(section_type, section_content, lifestyle_data)

# RAGAS 신뢰도 평가 도구 import
try:
    from mcp_server.tools.reliability_tools import evaluate_report_reliability, get_section_reliability
except ImportError:
    try:
        import importlib.util
        rel_path = mcp_server_dir / "tools" / "reliability_tools.py"
        spec = importlib.util.spec_from_file_location("reliability_tools", rel_path)
        rel_tools = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(rel_tools)
        evaluate_report_reliability = rel_tools.evaluate_report_reliability
        get_section_reliability = rel_tools.get_section_reliability
    except Exception as e:
        raise ImportError(f"Could not import reliability_tools: {e}")

@mcp.tool()
async def evaluate_report_with_ragas(report_state: dict, gemini_api_key: str = None):
    """
    LangGraph로 생성된 리포트의 신뢰도를 RAGAS로 평가합니다.
    
    Args:
        report_state: LangGraph ReportState 딕셔너리 (active_sections, section_queries, narrative_evidence, section_cards 포함)
        gemini_api_key: Gemini API Key (옵션, 없으면 환경변수 사용)
    
    Returns:
        {
            "success": bool,
            "scores": { 섹션별 점수 },
            "statistics": { 전체 통계 }
        }
    """
    return evaluate_report_reliability(report_state, gemini_api_key)

@mcp.tool()
async def evaluate_section_with_ragas(
    section: str,
    card_type: str,
    question: str,
    contexts: list,
    answer: str,
    gemini_api_key: str = None
):
    """
    단일 섹션-카드의 신뢰도를 RAGAS로 평가합니다.
    
    Args:
        section: 섹션 이름 (예: "sleep", "uv")
        card_type: 카드 타입 (예: "problem", "cause", "action")  
        question: 질문 (쿼리)
        contexts: 근거 텍스트 리스트
        answer: 생성된 답변
        gemini_api_key: Gemini API Key (옵션)
    
    Returns:
        {
            "success": bool,
            "score": { 평가 점수 정보 }
        }
    """
    return get_section_reliability(section, card_type, question, contexts, answer, gemini_api_key)

if __name__ == "__main__":
    mcp.run() # 이 줄이 있어야 Inspector와 통신이 가능합니다.