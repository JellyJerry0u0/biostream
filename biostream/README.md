# BioStream Flutter App

BioStream 모바일 앱(Flutter)입니다.  
현재 앱은 온보딩/인증/프로필/설문/결과 리포트/코치 챗/마이페이지 흐름을 포함합니다.

## 실행 위치 (중요)

모든 Flutter 명령은 이 폴더(`biostream/`)에서 실행합니다.

```bash
cd biostream
```

## 빠른 시작

```bash
flutter pub get
flutter run
```

## 시크릿/환경값

### `--dart-define-from-file` 권장

```bash
cp dev.secrets.json.example dev.secrets.json
flutter run --dart-define-from-file=dev.secrets.json
```

Windows에서는 `cp` 대신 `copy`를 사용하세요.

### Firebase 설정 파일 (커밋 금지)

`android/app/google-services.json`은 Git에 올리지 않습니다.

```bash
copy android\app\google-services.template.json android\app\google-services.json
```

## 구조 개요

- `lib/main.dart`: 앱 진입점
- `lib/screens/`: 화면 계층
- `lib/widgets/`: 공통/기능별 UI 컴포넌트
- `lib/services/`: API/스토리지/플랫폼 연동
- `lib/models/`: 데이터 모델
- `test/`: 단위/위젯 테스트

feature-first import 규칙과 리팩토링 정책은 아래 문서를 따릅니다.

- `REFACTORING_GUIDE.md`
- `FLUTTER_STRUCTURE_MAP.md`

## 품질 점검 명령

```bash
dart analyze
flutter test
```

