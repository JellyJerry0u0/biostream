#MCP 서버 메인 실행 파일(Gemini와 통신하는 입구)
# mcp/server.py 예시
from mcp.server.fastmcp import FastMCP
from backend.mcp_server.tools.db_tools import fetch_user_aging_context # 우리가 만든 함수

mcp = FastMCP("BioStream")

# 도구 등록
@mcp.tool()
async def get_user_health_report(user_id: int):
    """유저의 최신 건강 데이터를 카테고리별로 가져와 노화 분석 맥락을 제공합니다."""
    return fetch_user_aging_context(user_id)

if __name__ == "__main__":
    mcp.run() # 이 줄이 있어야 Inspector와 통신이 가능합니다.