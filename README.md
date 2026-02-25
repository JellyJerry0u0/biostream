# biostream_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local secrets (`--dart-define-from-file`)

API 키는 코드에 하드코딩하지 말고 로컬 비추적 파일로 관리하세요.

```bash
copy dev.secrets.json.example dev.secrets.json
flutter run --dart-define-from-file=dev.secrets.json
```

`dev.secrets.json`은 Git에 올라가지 않도록 `.gitignore`에 포함되어 있습니다.
