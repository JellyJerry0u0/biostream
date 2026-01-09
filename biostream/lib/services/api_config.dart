import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ApiConfig {
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

    // 개발 모드: 에뮬레이터/시뮬레이터 여부를 구분
    if (!kIsWeb && Platform.isAndroid) {
      final isEmulator = await _isEmulator();
      return isEmulator ? "http://10.0.2.2:8080" : "http://127.0.0.1:8080";
    }
    if (!kIsWeb && Platform.isIOS) {
      final isSimulator = await _isEmulator();
      return isSimulator ? "http://127.0.0.1:8080" : "http://127.0.0.1:8080";
    }

    // 기타 플랫폼 기본값
    return "http://127.0.0.1:8080";
  }

  static Future<bool> _isEmulator() async {
    // 웹에서는 에뮬레이터 체크 불필요
    if (kIsWeb) return false;

    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        // true면 실기기, false면 에뮬레이터
        return !info.isPhysicalDevice;
      }
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        // true면 실기기, false면 시뮬레이터
        return !info.isPhysicalDevice;
      }
    } catch (_) {
      // 정보 획득 실패 시 "실기기"로 간주(=자동 변환을 과신하지 않도록)
      return false;
    }
    return false;
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
