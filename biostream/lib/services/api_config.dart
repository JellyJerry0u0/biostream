import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiConfig {
  /// 카카오 Native App Key (developers.kakao.com에서 앱 생성 후 발급)
  /// 실제 키로 교체 후 사용하세요.
  static const String kakaoNativeAppKey = '2a989319843d4d7fa3409daeb094d0ca';

  static const String _keyBaseOrigin = 'api_base_origin';

  static const String _releaseOrigin =
      "https://api.biostream.com"; // TODO: 배포 시 실제 도메인으로 교체

  // 저장된 오리진 조회 (없으면 기본값)
  static Future<String> getBaseOrigin() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyBaseOrigin);
    if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    return _defaultOrigin();
  }

  // 기본 오리진(호스트 + 포트): 에뮬레이터/시뮬레이터는 자동, 실기기는 사용자가 설정하도록 유도
  static Future<String> _defaultOrigin() async {
    // 릴리즈 빌드에서는 고정 도메인 사용
    if (kReleaseMode) return _releaseOrigin;

    // 웹 플랫폼: localhost 사용
    if (kIsWeb) {
      return "http://localhost:8080";
    }

    // 개발 모드: 에뮬레이터/시뮬레이터 여부를 구분 (웹이 아닐 때만)
    return _getMobileOrigin();
  }

  // 모바일 플랫폼용 오리진 (웹에서는 호출되지 않음)
  static Future<String> _getMobileOrigin() async {
    if (kIsWeb) return "http://localhost:8080"; // 웹에서는 호출되지 않지만 안전장치

    final deviceInfo = DeviceInfoPlugin();
    try {
      // Android 체크
      try {
        final androidInfo = await deviceInfo.androidInfo;
        final isEmulator = !androidInfo.isPhysicalDevice;
        return isEmulator ? "http://10.0.2.2:8080" : "http://127.0.0.1:8080";
      } catch (_) {
        // Android가 아님
      }

      // iOS 체크
      try {
        final iosInfo = await deviceInfo.iosInfo;
        final isSimulator = !iosInfo.isPhysicalDevice;
        return isSimulator ? "http://127.0.0.1:8080" : "http://127.0.0.1:8080";
      } catch (_) {
        // iOS가 아님
      }
    } catch (_) {
      // 정보 획득 실패
    }

    // 기타 플랫폼 기본값
    return "http://127.0.0.1:8080";
  }

  // 오리진 저장
  static Future<void> setBaseOrigin(String origin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseOrigin, origin);
  }

  // 기본값으로 리셋
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBaseOrigin);
  }
}
