# 카카오 로그인 설정 가이드

카카오 로그인을 사용하려면 [카카오 개발자 콘솔](https://developers.kakao.com)에서 앱을 생성하고 Native App Key를 발급받은 뒤 아래 항목을 설정해야 합니다.

## 1. 카카오 개발자 콘솔 설정

1. [developers.kakao.com](https://developers.kakao.com) 접속 후 로그인
2. **내 애플리케이션** → **애플리케이션 추가하기**
3. 앱 생성 후 **앱 키** 탭에서 **Native 앱 키** 확인
4. **카카오 로그인** 메뉴에서 **활성화 설정 ON**
5. **플랫폼** 메뉴에서 Android/iOS 추가:
   - **Android**: 패키지명 `com.biostream.app`, 키 해시 등록 (debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`)
   - **iOS**: Bundle ID `com.biostream.app` 등록

## 2. 앱 코드 설정

아래 3곳에서 `YOUR_NATIVE_APP_KEY`를 발급받은 **Native 앱 키**로 교체하세요.

### lib/services/api_config.dart

```dart
static const String kakaoNativeAppKey = 'YOUR_NATIVE_APP_KEY';
```

### android/app/src/main/AndroidManifest.xml

```xml
<data android:scheme="kakaoYOUR_NATIVE_APP_KEY" android:host="oauth"/>
```

→ `kakaoYOUR_NATIVE_APP_KEY`를 `kakao` + 실제키 (예: `kakao1a2b3c4d5e6f`)로 변경

### ios/Runner/Info.plist

```xml
<string>kakaoYOUR_NATIVE_APP_KEY</string>
```

→ `kakaoYOUR_NATIVE_APP_KEY`를 `kakao` + 실제키로 변경

## 3. 동의 항목 (생년·생일·성별)

**비즈앱만** 생년·생일·성별 동의 항목을 활성화할 수 있습니다. (사업자등록 필요)

- **비즈앱이 아닌 경우**: 카카오에서 해당 정보 수집 권한이 없습니다.  
  → 카카오로 회원가입/로그인 후 **프로필 보완 화면**에서 성별·생년월일을 입력받아 `users` 테이블에 저장합니다. (리포트 개인화에 사용)
- **비즈앱인 경우**: 카카오 개발자 콘솔 **동의 항목**에서 생년·생일·성별을 **선택 동의**로 설정하면, 로그인 시 해당 정보를 받아 `users` 테이블에 저장됩니다.
