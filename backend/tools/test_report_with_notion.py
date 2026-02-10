"""
LangGraph with Notion Export 테스트
"""

import os
import sys

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
            print(f"✅ 환경변수 로드: {env_path}")
            break
except ImportError:
    print("⚠️ python-dotenv가 설치되지 않았습니다.")

from langgraph_modules.report_graph import generate_report


def test_report_with_notion():
    """Notion Export를 포함한 전체 워크플로우 테스트"""
    print("=" * 60)
    print("LangGraph + Notion Export 테스트")
    print("=" * 60)
    
    # Notion Export 활성화 (테스트용)
    os.environ["ENABLE_NOTION_EXPORT"] = "true"
    
    print("\n[1] 리포트 생성 시작 (user_id=1)")
    
    try:
        result = generate_report(user_id=1)
        
        if result.get("success"):
            print("\n" + "=" * 60)
            print("✅ 리포트 생성 및 Notion Export 완료")
            print("=" * 60)
            
            report = result.get("report", {})
            
            # 리포트 정보 출력
            print(f"\n📄 리포트 ID: {report.get('report_id')}")
            print(f"📅 생성 시간: {report.get('generated_at')}")
            print(f"📊 섹션 수: {len(report.get('sections', {}))}")
            
            # Notion 정보 출력
            if report.get("notion_page_id"):
                print(f"\n📝 Notion 페이지 ID: {report.get('notion_page_id')}")
                print(f"🔗 Notion URL: {report.get('notion_url')}")
            else:
                print(f"\n⚠️ Notion Export가 비활성화되었거나 실패했습니다.")
            
        else:
            print(f"\n❌ 리포트 생성 실패: {result.get('error')}")
            
    except Exception as e:
        print(f"\n❌ 테스트 오류: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    test_report_with_notion()
