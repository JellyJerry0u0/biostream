# Refactoring Guide (Flutter)

이 문서는 현재 `biostream` 앱에서 사용 중인 화면 리팩토링 표준을 정리합니다.
목표는 **파일 책임 분리**, **회귀 방지**, **팀 내 일관성**입니다.

## 1) 기본 구조

화면이 커질수록 아래 구조를 기본으로 사용합니다.

- `screen`:
  - 화면 상태, 페이지 조립, 라우팅/네비게이션만 담당
- `controller`:
  - API 호출, 데이터 변환, 에러 메시지 결정 등 비즈니스 로직 담당
- `widgets/pages`:
  - 화면 섹션 단위 UI
- `widgets/common`:
  - 여러 화면/페이지에서 재사용 가능한 공통 UI와 타입
- `labels/helper/metrics`:
  - 순수 함수(매핑/요약/계산) 분리

권장 예시:

- `lib/screens/survey_screen.dart`
- `lib/screens/survey/survey_controller.dart`
- `lib/screens/survey/survey_labels.dart`
- `lib/widgets/survey/pages/*`
- `lib/widgets/survey/common/*`

## 2) 파일 분리 기준

아래 중 2개 이상 해당하면 분리합니다.

- 단일 파일이 400~500줄 이상
- `Widget _build...` 메서드가 5개 이상
- API 호출/데이터 가공/위젯 렌더링이 혼합됨
- 동일 스타일/입력 UI가 여러 곳에 반복됨
- 테스트가 화면 전체 결합 때문에 어려움

## 3) 리팩토링 순서 (권장)

안전한 순서로 점진 분리합니다.

1. **순수 함수 먼저 분리**
   - label 변환, 요약 문자열, 계산 로직
2. **컨트롤러 분리**
   - 네트워크 호출 + 응답 매핑
3. **큰 UI 블록 분리**
   - 페이지/섹션 위젯으로 이동
4. **공통 위젯/타입 통합**
   - 중복 typedef, 버튼/폼 컴포넌트 통합
5. **스타일 기술부채 정리**
   - `withOpacity` -> `withValues(alpha: ...)`
6. **테스트 추가**
   - 순수 함수/헬퍼/컨트롤러 우선

## 4) 상태/책임 규칙

- `screen`에서 유지:
  - `setState`, `AnimationController`, `PageController`, 라우팅
- `controller`에서 유지:
  - API 결과를 화면에서 바로 쓰기 쉬운 모델로 변환
- `widgets/pages`:
  - 상태는 가능한 `props + callback`으로 주입
- 순수 함수:
  - `BuildContext`/플랫폼 의존 없이 테스트 가능해야 함

## 5) 테스트 최소 기준

리팩토링 대상마다 최소 아래는 추가합니다.

- `labels/helper` 테스트:
  - 매핑, 폴백, 조합 문자열
- `controller` 테스트:
  - 성공 응답 매핑
  - 실패 응답 매핑
- `visibility/state helper` 테스트(있는 경우):
  - 진입/이탈 전이 로직

테스트 파일 권장 위치:

- `test/survey/*`
- `test/future_face/*`

## 6) 체크리스트

리팩토링 PR 전에 다음을 확인합니다.

- `dart format` 통과
- `dart analyze` 에러/경고 없음 (info는 별도 정리 가능)
- 신규 분리 파일 네이밍이 역할과 일치
- 화면에서 불필요한 private helper 제거 완료
- `withOpacity(` 잔여 없음 (`rg "withOpacity\\(" lib`)
- 신규/변경 테스트 통과 (`flutter test ...`)

## 7) 네이밍 규칙

- 화면: `*_screen.dart`
- 컨트롤러: `*_controller.dart`
- 순수 로직: `*_labels.dart`, `*_helper.dart`, `*_metrics.dart`
- 섹션 위젯: `widgets/<feature>/pages/*.dart`
- 공통 위젯/타입: `widgets/<feature>/common/*.dart`

## 7-1) import 경로 규칙 (feature-first)

- 신규 코드는 feature 경로를 기본으로 import 합니다.
  - 예: `screens/result/result_screen.dart`
  - 예: `screens/coach/coach_chat_screen.dart`
- 루트 `screens/*_screen.dart`는 점진 전환 중인 호환 레이어로 간주합니다.
  - 새 코드에서 직접 import 금지
  - 기존 코드 호환 목적에서만 유지
- 경로 전환 시 원칙:
  1. 먼저 import를 feature 경로로 교체
  2. 분석/테스트 확인
  3. 마지막에 레거시 파일 제거 여부 판단

## 8) 금지/주의 사항

- 대형 리팩토링에서 기능 변경을 섞지 않기
- API 스키마 변경을 UI 리팩토링 커밋에 포함하지 않기
- 화면 로직과 스타일 마이그레이션을 한 번에 크게 섞지 않기
  - 가능하면 라운드 분리

---

이 가이드는 현재 `result`, `today_me`, `survey`, `future_face_compare` 리팩토링 경험을 기준으로 작성되었습니다.
새 화면에도 같은 패턴을 우선 적용하고, 예외가 필요하면 문서에 규칙을 업데이트합니다.
