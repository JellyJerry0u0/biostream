"""
Notion MCP 통합 도구
MCP (Model Context Protocol)를 사용하여 Notion API와 통신
"""

import os
import sys
import asyncio
import json
from datetime import datetime
from typing import Dict, Any, List, Optional

# 경로 설정
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.append(backend_dir)

# .env 파일 로드
try:
    from dotenv import load_dotenv
    env_paths = [
        os.path.join(os.path.dirname(__file__), '.env'),
        os.path.join(backend_dir, '.env'),
    ]
    for env_path in env_paths:
        if os.path.exists(env_path):
            load_dotenv(env_path)
            break
except ImportError:
    pass

# MCP import
try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
    MCP_AVAILABLE = True
except ImportError:
    MCP_AVAILABLE = False
    print("⚠️ MCP가 설치되지 않았습니다. pip install mcp를 실행하세요.")


def _format_generated_at_for_title(generated_at: Any) -> str:
    """리포트 생성 시각을 제목용으로 보기 좋게 포맷"""
    if generated_at is None:
        return "생성 시각 미상"

    dt: Optional[datetime] = None
    raw = str(generated_at).strip()
    if not raw:
        return "생성 시각 미상"

    if isinstance(generated_at, datetime):
        dt = generated_at
    else:
        normalized = raw.replace("Z", "+00:00")
        try:
            dt = datetime.fromisoformat(normalized)
        except Exception:
            try:
                dt = datetime.strptime(raw, "%Y-%m-%d %H:%M:%S")
            except Exception:
                return raw

    if dt.tzinfo is not None:
        try:
            dt = dt.astimezone()
        except Exception:
            pass

    period = "오전" if dt.hour < 12 else "오후"
    hour_12 = dt.hour % 12 or 12
    return f"{dt:%Y-%m-%d} {period} {hour_12}:{dt:%M}"


class NotionMCPClient:
    """Notion MCP 클라이언트"""
    
    def __init__(self):
        self.notion_token = os.getenv("NOTION_TOKEN")
        self.notion_database_id = os.getenv("NOTION_DATABASE_ID")
        self.notion_page_id = os.getenv("NOTION_PAGE_ID")
        
        if not MCP_AVAILABLE:
            print("❌ MCP가 설치되지 않았습니다.")
            return
        
        if not self.notion_token:
            print("⚠️ NOTION_TOKEN 환경변수가 설정되지 않았습니다.")
            return
        
        print("✅ Notion MCP 클라이언트 초기화 완료")
    
    async def _list_mcp_tools(self) -> List[str]:
        """사용 가능한 MCP 도구 목록 가져오기"""
        if not MCP_AVAILABLE:
            return []
        
        server_params = StdioServerParameters(
            command="npx",
            args=["-y", "@notionhq/notion-mcp-server"],
            env={"NOTION_TOKEN": self.notion_token}
        )
        
        try:
            async with stdio_client(server_params) as (read, write):
                async with ClientSession(read, write) as session:
                    await session.initialize()
                    
                    # 사용 가능한 도구 목록 가져오기
                    tools = await session.list_tools()
                    tool_names = [tool.name for tool in tools.tools]
                    
                    print(f"📋 사용 가능한 MCP 도구: {tool_names}")
                    return tool_names
        except Exception as e:
            print(f"⚠️ MCP 도구 목록 가져오기 실패: {e}")
            return []
    
    async def _call_mcp_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """MCP 도구 호출"""
        if not MCP_AVAILABLE:
            return {"success": False, "error": "MCP가 설치되지 않음"}
        
        # MCP 서버 파라미터 설정
        server_params = StdioServerParameters(
            command="npx",
            args=["-y", "@notionhq/notion-mcp-server"],
            env={"NOTION_TOKEN": self.notion_token}
        )
        
        try:
            # MCP 서버와 통신
            async with stdio_client(server_params) as (read, write):
                async with ClientSession(read, write) as session:
                    # 세션 초기화
                    await session.initialize()
                    
                    # 도구 호출
                    result = await session.call_tool(tool_name, arguments=arguments)
                    
                    return {
                        "success": True,
                        "result": result.content
                    }
        except Exception as e:
            print(f"❌ MCP 도구 호출 실패: {e}")
            import traceback
            traceback.print_exc()
            return {
                "success": False,
                "error": str(e)
            }

    @staticmethod
    def _extract_page_data(content_item: Any) -> Dict[str, Any]:
        """MCP content item에서 페이지 JSON(dict) 추출"""
        if isinstance(content_item, dict):
            return content_item

        raw_text = ""
        if hasattr(content_item, "text"):
            raw_text = getattr(content_item, "text") or ""
        elif isinstance(content_item, str):
            raw_text = content_item
        else:
            raw_text = str(content_item)

        raw_text = raw_text.strip()
        if not raw_text:
            return {}

        try:
            parsed = json.loads(raw_text)
            if isinstance(parsed, dict):
                return parsed
        except Exception:
            pass

        return {}
    
    def list_tools(self) -> List[str]:
        """사용 가능한 도구 목록 (동기 래퍼)"""
        return asyncio.run(self._list_mcp_tools())
    
    def create_page(self, title: str, blocks: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Notion 페이지 생성 (동기 래퍼)
        
        Args:
            title: 페이지 제목
            blocks: Notion Block 리스트
        
        Returns:
            생성 결과 (page_id 포함)
        """
        print(f"[Notion MCP] 페이지 생성 시작: {title}")
        print(f"[Notion MCP] 블록 개수: {len(blocks)}개")
        
        # 비동기 호출을 동기로 실행
        return asyncio.run(self._create_page_async(title, blocks))
    
    async def _create_page_async(self, title: str, blocks: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Notion 페이지 생성 (비동기)"""
        if not self.notion_page_id and not self.notion_database_id:
            print("❌ NOTION_DATABASE_ID 또는 NOTION_PAGE_ID가 설정되지 않았습니다.")
            return {
                "success": False,
                "error": "Notion parent 설정 누락"
            }
        
        try:
            # parent 설정
            if self.notion_database_id:
                parent = {"database_id": self.notion_database_id}
                # Database에 페이지 생성 시 properties 형식
                properties = {
                    "Name": {
                        "title": [
                            {
                                "type": "text",
                                "text": {"content": title}
                            }
                        ]
                    }
                }
            else:
                parent = {"page_id": self.notion_page_id}
                # Page 하위에 생성 시 properties 형식
                properties = {
                    "title": {
                        "title": [
                            {
                                "type": "text",
                                "text": {"content": title}
                            }
                        ]
                    }
                }
            
            # MCP를 통해 페이지 생성
            # Notion API 직접 호출 형식 사용
            arguments = {
                "parent": parent,
                "properties": properties,
                "children": blocks[:100]  # 첫 100개 블록만
            }
            
            result = await self._call_mcp_tool("API-post-page", arguments)
            
            if not result.get("success"):
                return result
            
            # 결과 파싱
            result_content = result.get("result", [])
            first_item = result_content[0] if result_content else {}
            page_data = self._extract_page_data(first_item)

            page_id = page_data.get("id") or page_data.get("page_id")
            page_url = page_data.get("url") or page_data.get("public_url")

            # 파싱 실패 fallback
            if not page_id:
                page_id = str(first_item).strip()
            if not page_url and page_id:
                page_url = f"https://notion.so/{page_id}"
            
            print(f"✅ [Notion MCP] 페이지 생성 완료 (페이지 ID: {page_id})")
            
            # 나머지 블록 추가
            if len(blocks) > 100:
                print(f"[Notion MCP] 나머지 블록 추가 중... ({len(blocks) - 100}개)")
                remaining_blocks = blocks[100:]
                await self._append_blocks_async(page_id, remaining_blocks)
            
            return {
                "success": True,
                "page_id": page_id,
                "url": page_url,
                "blocks_count": len(blocks)
            }
            
        except Exception as e:
            print(f"❌ [Notion MCP] 페이지 생성 실패: {e}")
            import traceback
            traceback.print_exc()
            return {
                "success": False,
                "error": str(e)
            }
    
    async def _append_blocks_async(self, page_id: str, blocks: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Notion 페이지에 블록 추가 (비동기)"""
        try:
            print(f"[Notion MCP] 블록 추가 시작 (페이지 ID: {page_id})")
            print(f"[Notion MCP] 추가할 블록 개수: {len(blocks)}개")
            
            # 100개씩 배치 처리
            batch_size = 100
            for i in range(0, len(blocks), batch_size):
                batch = blocks[i:i + batch_size]
                
                arguments = {
                    "block_id": page_id,
                    "children": batch
                }
                
                result = await self._call_mcp_tool("API-patch-block-children", arguments)
                
                if not result.get("success"):
                    print(f"⚠️ 배치 {i//batch_size + 1} 추가 실패")
                    continue
                
                print(f"  - {i + len(batch)}/{len(blocks)} 블록 추가 완료")
            
            print(f"✅ [Notion MCP] 모든 블록 추가 완료")
            
            return {
                "success": True,
                "blocks_count": len(blocks)
            }
            
        except Exception as e:
            print(f"❌ [Notion MCP] 블록 추가 실패: {e}")
            return {
                "success": False,
                "error": str(e)
            }


def export_report_to_notion(final_report: Dict[str, Any]) -> Dict[str, Any]:
    """
    완성된 리포트를 Notion으로 전송 (LangGraph에서 호출)
    
    Args:
        final_report: LangGraph에서 생성된 최종 리포트
    
    Returns:
        전송 결과
    """
    try:
        # 1. Notion Block으로 변환
        from tools.notion_formatter import format_report_to_notion
        
        print("[Notion Export] 리포트를 Notion Block으로 변환 중...")
        blocks = format_report_to_notion(final_report)
        print(f"✅ [Notion Export] {len(blocks)}개 블록 변환 완료")
        
        # 2. Notion MCP 클라이언트 초기화
        client = NotionMCPClient()
        
        # 3. 페이지 제목 생성
        survey_summary = final_report.get("survey_summary", {})
        outcomes = survey_summary.get("outcomes", [])
        generated_at = _format_generated_at_for_title(final_report.get("generated_at", ""))
        user_name = final_report.get("user_name", "사용자")
        
        #사용자 이름이 제목에 포함되게 수정 ex> "***사용자의 분석 리포트 결과- 2026-02-10 15:30:00"
        title = f"{user_name}님의 분석 리포트 결과 - {generated_at}"
        
        # 4. Notion 페이지 생성
        result = client.create_page(title=title, blocks=blocks)
        
        if result.get("success"):
            print(f"✅ [Notion Export] Notion 페이지 생성 완료")
            print(f"   - 페이지 ID: {result.get('page_id')}")
            print(f"   - URL: {result.get('url')}")
            return result
        else:
            print(f"⚠️ [Notion Export] 페이지 생성 실패: {result.get('error')}")
            return result
            
    except Exception as e:
        print(f"❌ [Notion Export] 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e)
        }


def export_report_from_db_to_notion(
    user_id: int,
    lifestyle_id: Optional[int] = None
) -> Dict[str, Any]:
    """
    DB에서 리포트를 불러와 Notion으로 Export (테스트용)
    
    Args:
        user_id: 사용자 ID
        lifestyle_id: Lifestyle ID (선택, 없으면 최신 리포트)
    
    Returns:
        Export 결과
    """
    print(f"=== Notion Export (DB) 시작 ===")
    print(f"User ID: {user_id}")
    if lifestyle_id:
        print(f"Lifestyle ID: {lifestyle_id}")
    
    try:
        # 1. DB에서 리포트 로드
        from tools.notion_formatter import load_report_from_db, format_report_to_notion
        
        final_report = load_report_from_db(user_id, lifestyle_id)
        
        if not final_report:
            return {
                "success": False,
                "error": f"User {user_id}의 리포트를 찾을 수 없습니다"
            }
        
        print(f"✅ 리포트 로드 완료")
        
        # 2. Notion Block으로 변환
        blocks = format_report_to_notion(final_report)
        print(f"✅ [Notion Export] {len(blocks)}개 블록 변환 완료")
        
        # 3. 페이지 제목 생성
        survey_summary = final_report.get("survey_summary", {})
        outcomes = survey_summary.get("outcomes", [])
        generated_at = _format_generated_at_for_title(final_report.get("generated_at", ""))
        user_name = final_report.get("user_name", "사용자")
        title = f"{user_name}님의 분석 리포트 결과 - {generated_at}"
        
        # 4. Notion MCP Client로 페이지 생성
        client = NotionMCPClient()
        notion_result = client.create_page(title, blocks)
        
        if notion_result["success"]:
            print(f"🎉 Notion Export 완료!")
            print(f"   페이지 URL: {notion_result.get('url', 'N/A')}")
        
        return notion_result
        
    except Exception as e:
        print(f"❌ Notion Export 실패: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e)
        }


def test_notion_connection():
    """Notion MCP 연결 테스트"""
    print("=== Notion MCP 연결 테스트 ===\n")
    
    # 환경변수 확인
    notion_token = os.getenv("NOTION_TOKEN")
    notion_database_id = os.getenv("NOTION_DATABASE_ID")
    notion_page_id = os.getenv("NOTION_PAGE_ID")
    enable_export = os.getenv("ENABLE_NOTION_EXPORT", "false").lower() == "true"
    
    print("📋 환경 변수:")
    print(f"  ENABLE_NOTION_EXPORT: {enable_export}")
    print(f"  NOTION_TOKEN: {'설정됨' if notion_token else '❌ 미설정'}")
    print(f"  NOTION_DATABASE_ID: {notion_database_id if notion_database_id else '미설정'}")
    print(f"  NOTION_PAGE_ID: {notion_page_id if notion_page_id else '미설정'}")
    print()
    
    if not enable_export:
        print("⚠️ ENABLE_NOTION_EXPORT=false입니다. true로 설정하세요.")
        return False
    
    if not notion_token:
        print("❌ NOTION_TOKEN이 설정되지 않았습니다.")
        return False
    
    if not notion_database_id and not notion_page_id:
        print("❌ NOTION_DATABASE_ID 또는 NOTION_PAGE_ID가 설정되지 않았습니다.")
        return False
    
    # 클라이언트 초기화 테스트
    try:
        client = NotionMCPClient()
        
        print("✅ Notion MCP 클라이언트 초기화 성공\n")
        
        # 사용 가능한 도구 목록 확인
        print("📋 사용 가능한 MCP 도구 확인 중...")
        tools = client.list_tools()
        
        if not tools:
            print("⚠️ MCP 도구를 가져올 수 없습니다. Node.js와 npx가 설치되어 있는지 확인하세요.")
            return False
        
        print(f"✅ 사용 가능한 도구: {', '.join(tools)}\n")
        
        # 간단한 테스트 페이지 생성
        print("📝 테스트 페이지 생성 중...")
        test_blocks = [
            {
                "object": "block",
                "type": "heading_2",
                "heading_2": {
                    "rich_text": [{"type": "text", "text": {"content": "테스트 페이지"}}]
                }
            },
            {
                "object": "block",
                "type": "paragraph",
                "paragraph": {
                    "rich_text": [{"type": "text", "text": {"content": "Notion MCP 연결 테스트가 성공했습니다! 🎉"}}]
                }
            }
        ]
        
        result = client.create_page("BioStream MCP 연결 테스트", test_blocks)
        
        if result["success"]:
            print("✅ 테스트 성공!")
            print(f"   페이지 URL: {result.get('url', 'N/A')}")
            print("\n👉 Notion에서 페이지를 확인하세요!")
            return True
        else:
            print(f"❌ 테스트 실패: {result.get('error', 'Unknown error')}")
            return False
            
    except Exception as e:
        print(f"❌ 예외 발생: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_notion_export():
    """Notion Export 테스트 (샘플 데이터)"""
    print("=" * 60)
    print("Notion Export 테스트 (샘플 데이터)")
    print("=" * 60)
    
    # 샘플 리포트
    sample_report = {
        "tabs": ["sleep"],
        "sections": {
            "sleep": {
                "title": "수면 및 리듬",
                "cards": [
                    {
                        "type": "problem",
                        "text": "당신의 수면 시간은 평균 5.5시간으로 권장 수면 시간(7-9시간)보다 크게 부족합니다."
                    }
                ]
            }
        },
        "survey_summary": {
            "outcomes": ["acne", "wrinkles"],
            "target_years": 30
        },
        "generated_at": "2026-02-10 15:30:00"
    }
    
    result = export_report_to_notion(sample_report)
    
    if result.get("success"):
        print(f"\n✅ 테스트 성공")
    else:
        print(f"\n⚠️ 테스트 실패: {result.get('error')}")
    
    return result


if __name__ == "__main__":
    """테스트 실행"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Notion MCP Export 테스트")
    parser.add_argument("--test-connection", action="store_true", help="Notion MCP 연결 테스트만 수행")
    parser.add_argument("--sample", action="store_true", help="샘플 리포트로 Export 테스트")
    parser.add_argument("--user-id", type=int, default=1, help="User ID (DB 테스트용)")
    parser.add_argument("--lifestyle-id", type=int, help="Lifestyle ID (선택)")
    
    args = parser.parse_args()
    
    if args.test_connection:
        # 연결 테스트만 수행
        success = test_notion_connection()
        sys.exit(0 if success else 1)
    elif args.sample:
        # 샘플 데이터로 Export 테스트
        result = test_notion_export()
        sys.exit(0 if result.get("success") else 1)
    else:
        # DB에서 리포트를 불러와 Export
        result = export_report_from_db_to_notion(
            user_id=args.user_id,
            lifestyle_id=args.lifestyle_id
        )
        
        # 결과 출력
        if result["success"]:
            print("\n✅ 성공!")
            print(f"   페이지 ID: {result.get('page_id', 'N/A')}")
            print(f"   페이지 URL: {result.get('url', 'N/A')}")
            print(f"   블록 개수: {result.get('blocks_count', 0)}")
            sys.exit(0)
        else:
            print(f"\n❌ 실패: {result.get('error', 'Unknown error')}")
            sys.exit(1)
