"""
이미지 생성 기능만 빠르게 테스트하는 스크립트
"""
import sys
import os

# 경로 설정
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.append(backend_dir)

from report_modules.report_graph import generate_report

def test_image_generation():
    """기존 lifestyle 데이터로 리포트 + 이미지 생성 테스트"""
    
    print("=" * 60)
    print("🧪 이미지 생성 기능 테스트 시작")
    print("=" * 60)
    
    # 기존 데이터 사용 (lifestyle_id=9, user_id=4)
    user_id = 4
    lifestyle_id = 9
    
    print(f"\n📋 테스트 대상:")
    print(f"   - user_id: {user_id}")
    print(f"   - lifestyle_id: {lifestyle_id}")
    print("\n🚀 리포트 + 이미지 생성 시작...")
    print("-" * 60)
    
    try:
        # 리포트 생성 (이미지도 함께 생성됨)
        result = generate_report(user_id=user_id, lifestyle_id=lifestyle_id)
        
        print("\n" + "=" * 60)
        if result.get("success"):
            print("✅ 성공!")
            print("=" * 60)
            
            report = result.get("report", {})
            
            # 🎯 우리가 추가한 부분만 출력
            print("\n🖼️  이미지 생성 결과:")
            print(f"   ├─ URL: {report.get('generated_image_url')}")
            print(f"   ├─ 상태: {report.get('generation_status')}")
            print(f"   └─ 파라미터: {report.get('image_gen_params')}")
            
            print("\n📊 리포트:")
            print(f"   ├─ Report ID: {report.get('report_id')}")
            print(f"   ├─ 생성 시간: {report.get('generated_at')}")
            print(f"   └─ 섹션 수: {len(report.get('sections', {}))}")
            
        else:
            print("❌ 실패!")
            print("=" * 60)
            print(f"   오류: {result.get('error')}")
            
    except Exception as e:
        print("\n" + "=" * 60)
        print("❌ 예외 발생!")
        print("=" * 60)
        print(f"   {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_image_generation()
