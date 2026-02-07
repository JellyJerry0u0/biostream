"""
MCP 클라이언트 유틸리티

MCP 서버의 도구들을 호출하는 클라이언트입니다.
같은 프로세스 내에서 실행되므로 직접 함수를 import하여 사용합니다.
"""

import sys
import os
from pathlib import Path
from typing import Dict, Any, Optional

# MCP 서버 경로 설정
backend_dir = Path(__file__).parent.parent.parent.absolute()
mcp_server_dir = backend_dir / "mcp_server"

# PYTHONPATH에 추가
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))
if str(mcp_server_dir) not in sys.path:
    sys.path.insert(0, str(mcp_server_dir))


def get_user_health_data(user_id: int) -> Dict[str, Any]:
    """
    MCP 도구를 통해 유저 건강 데이터를 조회합니다.
    
    Args:
        user_id: 사용자 ID
    
    Returns:
        유저 건강 데이터 딕셔너리
    """
    try:
        from mcp_server.tools.db_tools import fetch_user_aging_context
        return fetch_user_aging_context(user_id)
    except ImportError:
        # fallback
        import importlib.util
        db_tools_path = mcp_server_dir / "tools" / "db_tools.py"
        spec = importlib.util.spec_from_file_location("db_tools", db_tools_path)
        db_tools = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(db_tools)
        return db_tools.fetch_user_aging_context(user_id)
    except Exception as e:
        return {"error": f"Failed to fetch user health data: {str(e)}"}


def validate_section(section_content: str, section_type: str) -> Dict[str, Any]:
    """
    리포트 섹션이 구조화된 형식인지 검증합니다.
    
    Args:
        section_content: 검증할 섹션 내용
        section_type: 섹션 타입
    
    Returns:
        검증 결과 딕셔너리
    """
    try:
        from mcp_server.tools.validation_tools import validate_section_structure
        return validate_section_structure(section_content, section_type)
    except ImportError:
        import importlib.util
        validation_path = mcp_server_dir / "tools" / "validation_tools.py"
        spec = importlib.util.spec_from_file_location("validation_tools", validation_path)
        validation_tools = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(validation_tools)
        return validation_tools.validate_section_structure(section_content, section_type)
    except Exception as e:
        return {"error": f"Failed to validate section: {str(e)}", "is_valid": False}


def create_visualization(
    section_type: str,
    section_content: str,
    lifestyle_data: Dict[str, Any]
) -> Dict[str, Any]:
    """
    리포트 섹션에 대한 시각자료를 생성합니다.
    
    Args:
        section_type: 섹션 타입
        section_content: 섹션 내용
        lifestyle_data: 생활습관 데이터
    
    Returns:
        시각자료 정보 딕셔너리
    """
    try:
        from mcp_server.tools.visualization_tools import generate_visualization
        return generate_visualization(section_type, section_content, lifestyle_data)
    except ImportError:
        import importlib.util
        viz_path = mcp_server_dir / "tools" / "visualization_tools.py"
        spec = importlib.util.spec_from_file_location("visualization_tools", viz_path)
        viz_tools = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(viz_tools)
        return viz_tools.generate_visualization(section_type, section_content, lifestyle_data)
    except Exception as e:
        return {"success": False, "error": f"Failed to create visualization: {str(e)}"}
