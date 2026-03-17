# Flutter Structure Map

이 문서는 현재 `biostream/lib` 구조를 빠르게 이해하고, 목표 구조로 정리하기 위한 맵입니다.

## 현재 구조 (요약)

### 1) 리팩토링 적용된 feature

- `survey`
  - `screens/survey_screen.dart`
  - `screens/survey/survey_controller.dart`
  - `screens/survey/survey_labels.dart`
  - `widgets/survey/pages/*`
  - `widgets/survey/common/*`
- `result`
  - `screens/result_screen.dart`
  - `screens/result/result_screen_controller.dart`
  - `screens/result/result_screen_helper.dart`
  - `screens/result/result_screen_metrics.dart`
  - `widgets/result/*`
- `today_me`
  - `screens/today_me_screen.dart`
  - `screens/today_me/today_me_controller.dart`
  - `screens/today_me/today_me_models.dart`
  - `widgets/today_me/today_me_content.dart`
- `future_face_compare`
  - `screens/future_face_compare_screen.dart`
  - `screens/future_face/future_face_compare_controller.dart`
  - `screens/future_face/future_face_visibility_helper.dart`
  - `widgets/future_face/*`

### 2) 상대적으로 대형/미분리 화면

- `screens/home_screen.dart`
- `screens/my_info_screen.dart`
- 인증/온보딩 계열 일부
  - `screens/login_screen.dart`
  - `screens/signup_screen.dart`
  - `screens/onboarding_screen.dart`
  - `screens/profile_completion_screen.dart`

### 3) 공통 계층

- `services/*` (API/인증/프로필/코치 WS/알림 등)
- `widgets/*` (글로벌/도메인 위젯 혼재)
- `models/*` (현재는 일부만 존재)

## 한눈에 보기 어려운 이유

- feature마다 패턴이 다름(분리된 화면 vs 대형 단일 화면)
- 결과/리포트 관련 위젯이 여러 위치로 분산
- 서비스 응답이 `Map<String, dynamic>` 중심이라 화면별 파싱 로직이 분산

## 목표 구조 (권장)

아래처럼 feature-first로 점진 통일:

```text
lib/
  features/
    survey/
      presentation/
        survey_screen.dart
        widgets/...
      application/
        survey_controller.dart
      domain/
        survey_labels.dart
    result/
      presentation/...
      application/...
      domain/...
    today_me/
      presentation/...
      application/...
      domain/...
    future_face/
      presentation/...
      application/...
      domain/...
  core/
    services/
    widgets/
    utils/
    models/
```

## 점진 이관 순서

1. `home_screen.dart` 분리 (`controller + section widgets`)
2. `my_info_screen.dart` 분리
3. 인증/온보딩 계열 공통 폼/레이아웃 추출
4. `widgets/report_cards/*`를 result feature 하위로 재배치
5. 서비스 응답 DTO 도입으로 화면 파싱 로직 축소

## 체크리스트

- 화면 파일은 상태/조립만 담당하는가?
- API 호출/매핑은 controller 또는 service에 있는가?
- 공통 UI는 `widgets/<feature>/common` 또는 `core/widgets`에 있는가?
- 해당 feature에 최소 단위 테스트가 있는가?
