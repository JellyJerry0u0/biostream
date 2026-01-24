"""
Google Cloud 인증 설정 헬퍼
브라우저를 통한 OAuth 인증 수행
"""
import subprocess
import sys
import os

def find_gcloud():
    """gcloud 실행 파일 찾기"""
    possible_paths = [
        r"C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        r"C:\Program Files\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd",
        os.path.expanduser(r"~\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"),
    ]
    
    for path in possible_paths:
        if os.path.exists(path):
            print(f"✓ gcloud 발견: {path}")
            return path
    
    print("✗ gcloud를 찾을 수 없습니다.")
    print("\n대안:")
    print("1. 브라우저에서 직접 인증:")
    print("   https://console.cloud.google.com/")
    print("   → API 및 서비스 → 사용자 인증 정보 → 서비스 계정 키 생성")
    print("\n2. 또는 수동으로 실행:")
    print("   C:\\Program Files (x86)\\Google\\Cloud SDK\\google-cloud-sdk\\bin\\gcloud.cmd auth application-default login")
    return None

def main():
    print("=" * 80)
    print("Google Cloud 인증 설정")
    print("=" * 80)
    
    gcloud_path = find_gcloud()
    
    if gcloud_path:
        print("\n인증 시작 중... (브라우저가 열립니다)")
        try:
            subprocess.run([gcloud_path, "auth", "application-default", "login"], check=True)
            print("\n✓ 인증 완료!")
            print("\n이제 다음 명령으로 테스트하세요:")
            print("  python aging_image_generator.py")
        except subprocess.CalledProcessError as e:
            print(f"\n✗ 인증 실패: {e}")
            print("\n수동 방법을 사용하세요 (위 안내 참조)")
    else:
        print("\n대체 인증 방법:")
        print("=" * 80)
        print("\n옵션 1: 서비스 계정 키 사용 (권장)")
        print("-" * 80)
        print("1. https://console.cloud.google.com/ 접속")
        print("2. 프로젝트 선택: 430662137711")
        print("3. '탐색 메뉴' → 'IAM 및 관리자' → '서비스 계정'")
        print("4. '서비스 계정 만들기' 클릭")
        print("   - 이름: biostream-vertex-ai")
        print("   - 역할: Vertex AI 사용자")
        print("5. 서비스 계정 → '키' → '키 추가' → JSON 다운로드")
        print("6. JSON 파일을 ai_service 폴더에 저장")
        print("7. .env 파일에 추가:")
        print("   GOOGLE_APPLICATION_CREDENTIALS=서비스계정키.json")
        
        print("\n옵션 2: AI Studio 웹 UI 사용")
        print("-" * 80)
        print("1. https://aistudio.google.com/")
        print("2. 프롬프트 복사 & 이미지 업로드")
        print("3. 수동으로 이미지 생성")

if __name__ == "__main__":
    main()
