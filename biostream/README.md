# SkinAI Onboarding - Flutter App

HTML 온보딩 페이지를 Flutter로 변환한 스마트폰 앱입니다.

## 기능

- 3개의 온보딩 슬라이드 (캐러셀)
  - AI로 미리 보는 10년 후 내 얼굴
  - 오늘의 습관이 내일의 얼굴을 만듭니다
  - 데이터로 관리하는 스마트 안티에이징
- 다크 모드 지원
- 스와이프 제스처로 슬라이드 전환
- 하단 인디케이터 도트
- Material Icons 사용

## 설치 및 실행

1. Flutter SDK가 설치되어 있는지 확인하세요:
```bash
flutter --version
```

2. 프로젝트 의존성 설치:
```bash
flutter pub get
```

3. 앱 실행:
```bash
flutter run
```

## 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점
├── screens/
│   └── onboarding_screen.dart  # 온보딩 화면 메인 위젯
└── widgets/
    ├── onboarding_slide.dart   # 각 슬라이드 위젯
    └── slide_indicator.dart    # 슬라이드 인디케이터
```

## 주요 특징

- **PageView 기반 캐러셀**: 스와이프로 슬라이드 전환
- **애니메이션**: 슬라이드 2의 바운싱 아이콘 애니메이션
- **커스텀 페인터**: 슬라이드 1의 스캔 라인 효과
- **반응형 디자인**: 다양한 화면 크기 지원
- **다크 모드**: 시스템 설정에 따라 자동 전환

## 다음 단계

- 로그인 화면 구현
- 회원가입 화면 구현
- 메인 앱 화면 구현

