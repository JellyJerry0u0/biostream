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

if __name__ == "__main__":
    mcp.run() # 이 줄이 있어야 Inspector와 통신이 가능합니다.