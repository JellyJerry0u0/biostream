"""
Notion 통합 도구
Notion API를 사용하여 리포트를 Notion 페이지로 생성
"""

import os
import sys
import time
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

# Notion SDK import
try:
    from notion_client import Client
    NOTION_SDK_AVAILABLE = True
except ImportError:
    NOTION_SDK_AVAILABLE = False
    print("⚠️ notion-client가 설치되지 않았습니다. pip install notion-client를 실행하세요.")


class NotionMCPClient:
    """Notion API 클라이언트"""
    
    def __init__(self):
        self.notion_token = os.getenv("NOTION_TOKEN")
        self.notion_database_id = os.getenv("NOTION_DATABASE_ID")
        self.notion_page_id = os.getenv("NOTION_PAGE_ID")  # Database 대신 Page에 작성하는 옵션
        
        self.client = None
        
        if not NOTION_SDK_AVAILABLE:
            print("❌ notion-client가 설치되지 않았습니다.")
            return
        
        if not self.notion_token:
            print("⚠️ NOTION_TOKEN 환경변수가 설정되지 않았습니다.")
            return
        
        # Notion 클라이언트 초기화
        try:
            self.client = Client(auth=self.notion_token)
            print("✅ Notion 클라이언트 초기화 완료")
        except Exception as e:
            print(f"❌ Notion 클라이언트 초기화 실패: {e}")
    
    def create_page(self, title: str, blocks: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Notion 페이지 생성
        
        Args:
            title: 페이지 제목
            blocks: Notion Block 리스트
        
        Returns:
            생성 결과 (page_id 포함)
        """
        if not self.client:
            print("❌ Notion 클라이언트가 초기화되지 않았습니다.")
            return {
                "success": False,
                "error": "Notion 클라이언트 초기화 실패"
            }
        
        try:
            print(f"[Notion API] 페이지 생성 시작: {title}")
            print(f"[Notion API] 블록 개수: {len(blocks)}개")
            
            # 페이지 생성 (Database 또는 Page 하위)
            if self.notion_database_id:
                # Database에 페이지 생성
                parent = {"database_id": self.notion_database_id}
                properties = {
                    "Name": {
                        "title": [
                            {
                                "text": {
                                    "content": title
                                }
                            }
                        ]
                    }
                }
            elif self.notion_page_id:
                # 기존 페이지의 하위 페이지로 생성
                parent = {"page_id": self.notion_page_id}
                properties = {
                    "title": [
                        {
                            "text": {
                                "content": title
                            }
                        }
                    ]
                }
            else:
                print("❌ NOTION_DATABASE_ID 또는 NOTION_PAGE_ID가 설정되지 않았습니다.")
                return {
                    "success": False,
                    "error": "Notion parent 설정 누락"
                }
            
            # Notion API는 한 번에 100개 블록만 추가 가능
            # 블록을 100개씩 나눠서 처리
            blocks_batch_size = 100
            initial_blocks = blocks[:blocks_batch_size]
            
            # 페이지 생성
            response = self.client.pages.create(
                parent=parent,
                properties=properties,
                children=initial_blocks
            )
            
            page_id = response["id"]
            page_url = response["url"]
            
            print(f"✅ [Notion API] 페이지 생성 완료 (페이지 ID: {page_id})")
            
            # 나머지 블록 추가
            if len(blocks) > blocks_batch_size:
                print(f"[Notion API] 나머지 블록 추가 중... ({len(blocks) - blocks_batch_size}개)")
                remaining_blocks = blocks[blocks_batch_size:]
                self.append_blocks(page_id, remaining_blocks)
            
            return {
                "success": True,
                "page_id": page_id,
                "url": page_url,
                "blocks_count": len(blocks)
            }
            
        except Exception as e:
            print(f"❌ [Notion API] 페이지 생성 실패: {e}")
            import traceback
            traceback.print_exc()
            return {
                "success": False,
                "error": str(e)
            }
    
    def append_blocks(self, page_id: str, blocks: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Notion 페이지에 블록 추가
        
        Args:
            page_id: 페이지 ID
            blocks: 추가할 Notion Block 리스트
        
        Returns:
            추가 결과
        """
        if not self.client:
            print("❌ Notion 클라이언트가 초기화되지 않았습니다.")
            return {
                "success": False,
                "error": "Notion 클라이언트 초기화 실패"
            }
        
        try:
            print(f"[Notion API] 블록 추가 시작 (페이지 ID: {page_id})")
            print(f"[Notion API] 추가할 블록 개수: {len(blocks)}개")
            
            # Notion API는 한 번에 100개 블록만 추가 가능
            batch_size = 100
            total_batches = (len(blocks) + batch_size - 1) // batch_size
            
            for batch_num, i in enumerate(range(0, len(blocks), batch_size), 1):
                batch = blocks[i:i + batch_size]
                self.client.blocks.children.append(
                    block_id=page_id,
                    children=batch
                )
                print(f"  - 배치 {batch_num}/{total_batches}: {i + len(batch)}/{len(blocks)} 블록 추가 완료")
                
                # Rate limiting 방지를 위한 짧은 대기 (마지막 배치는 제외)
                if i + batch_size < len(blocks):
                    time.sleep(0.3)
            
            print(f"✅ [Notion API] 모든 블록 추가 완료")
            
            return {
                "success": True,
                "blocks_count": len(blocks)
            }
            
        except Exception as e:
            print(f"❌ [Notion API] 블록 추가 실패: {e}")
            import traceback
            traceback.print_exc()
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
        generated_at = final_report.get("generated_at", "")
        
        title = f"BioStream 리포트 - {', '.join(outcomes[:2])} - {generated_at}"
        
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
        generated_at = final_report.get("generated_at", "")
        title = f"BioStream 리포트 - User {user_id} - {', '.join(outcomes[:2])} - {generated_at}"
        
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
    """Notion API 연결 테스트"""
    print("=== Notion API 연결 테스트 ===\n")
    
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
        print("   NOTION_SETUP_GUIDE.md를 참고하여 설정하세요.")
        return False
    
    if not notion_database_id and not notion_page_id:
        print("❌ NOTION_DATABASE_ID 또는 NOTION_PAGE_ID가 설정되지 않았습니다.")
        print("   NOTION_SETUP_GUIDE.md를 참고하여 설정하세요.")
        return False
    
    # 클라이언트 초기화 테스트
    try:
        client = NotionMCPClient()
        if not client.client:
            print("❌ Notion 클라이언트 초기화 실패")
            return False
        
        print("✅ Notion 클라이언트 초기화 성공\n")
        
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
                    "rich_text": [{"type": "text", "text": {"content": "Notion API 연결 테스트가 성공했습니다! 🎉"}}]
                }
            }
        ]
        
        result = client.create_page("BioStream 연결 테스트", test_blocks)
        
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


# 테스트 함수 (샘플 데이터로 Export)
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
    
    parser = argparse.ArgumentParser(description="Notion Export 테스트")
    parser.add_argument("--test-connection", action="store_true", help="Notion API 연결 테스트만 수행")
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

