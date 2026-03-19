//백엔드와 통신을 담당할 파일
import 'dart:convert';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  final storage = const FlutterSecureStorage();
  static const String _nativeAuthTokenKey = 'auth_bearer_token';

  Future<void> _mirrorTokenToNative(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nativeAuthTokenKey, token);
  }

  Future<void> _clearNativeTokenMirror() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nativeAuthTokenKey);
  }

  /// 명시적 로그아웃 처리
  /// - 로컬 JWT 토큰 삭제
  /// - 카카오 세션이 있으면 함께 종료(실패해도 로컬 로그아웃은 유지)
  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오 세션 종료 실패는 무시하고 로컬 로그아웃을 진행합니다.
    } finally {
      await storage.delete(key: 'jwt_token');
      await _clearNativeTokenMirror();
    }
  }

  /// 앱 시작 시 저장된 토큰으로 세션 복원 가능 여부를 확인합니다.
  ///
  /// - 토큰 없음: false
  /// - 200 응답: true
  /// - 401/403: 토큰 삭제 후 false
  /// - 네트워크/일시 오류: 토큰이 있으면 true (불필요한 재로그인 방지)
  Future<bool> hasValidSession() async {
    final token = await storage.read(key: 'jwt_token');
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final origin = await ApiConfig.getBaseOrigin();
      final response = await http
          .get(
            Uri.parse('$origin/auth/me'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await storage.delete(key: 'jwt_token');
        await _clearNativeTokenMirror();
        return false;
      }

      return true;
    } catch (_) {
      return true;
    }
  }

  // 회원가입 요청
  Future<Map<String, dynamic>> signUp(
    String email,
    String password,
    String nickname,
    String birthdate,  // 필수
    String gender,  // 필수
    bool? isPregnant,  // 임신 여부 (여성일 경우에만, 선택)
  ) async {
    try {
      final origin = await ApiConfig.getBaseOrigin();
      final body = {
        "email": email,
        "password": password,
        "nickname": nickname,
        "birthdate": birthdate,
        "gender": gender,
        if (isPregnant != null) "is_pregnant": isPregnant,
      };
      
      final response = await http.post(
        Uri.parse('$origin/auth/signup'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        return {"success": true, "message": "회원가입 완료"};
      } else {
        final body = jsonDecode(response.body);
        final detail = body['detail'];
        // detail이 리스트일 수도 있고 문자열일 수도 있음
        String message;
        if (detail is List) {
          message = detail.map((e) => e['msg'] ?? e.toString()).join(', ');
        } else {
          message = detail?.toString() ?? "회원가입 실패";
        }
        return {"success": false, "message": message};
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패"};
    }
  }

  // 로그인 요청 및 토큰 저장
  Future<Map<String, dynamic>> login(String email, String password) async {
    String origin = '';
    try {
      origin = await ApiConfig.getBaseOrigin();
      final response = await http.post(
        Uri.parse('$origin/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // JWT 토큰을 기기에 안전하게 저장
        final accessToken = data['access_token'] as String;
        await storage.write(key: 'jwt_token', value: accessToken);
        await _mirrorTokenToNative(accessToken);
        return {
          "success": true,
          "nickname": data['nickname'],
          "user_id": data['user_id'],
        };
      } else {
        String message = "이메일 또는 비밀번호가 틀렸습니다.";
        try {
          final body = jsonDecode(response.body);
          final detail = body['detail'];
          if (detail != null) {
            message = detail.toString();
          }
        } catch (_) {}
        return {"success": false, "message": message};
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패 ($origin): $e"};
    }
  }

  /// 카카오 로그인: 카카오 SDK로 인증 후 백엔드에 사용자 정보 전달
  Future<Map<String, dynamic>> loginWithKakao() async {
    try {
      // 1. 카카오 로그인 (카카오톡 또는 카카오계정)
      OAuthToken oauthToken;
      final talkInstalled = await isKakaoTalkInstalled();
      if (talkInstalled) {
        try {
          oauthToken = await UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          if (e is PlatformException && e.code == 'CANCELED') {
            return {"success": false, "message": "로그인이 취소되었습니다."};
          }
          oauthToken = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        oauthToken = await UserApi.instance.loginWithKakaoAccount();
      }

      // 3. 백엔드 카카오 로그인 API 호출
      final origin = await ApiConfig.getBaseOrigin();
      final body = {
        "access_token": oauthToken.accessToken,
      };

      final response = await http.post(
        Uri.parse('$origin/auth/kakao-login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        await storage.write(key: 'jwt_token', value: accessToken);
        await _mirrorTokenToNative(accessToken);
        return {
          "success": true,
          "nickname": data['nickname'],
          "needs_profile": data['needs_profile'] == true,
        };
      } else {
        final body = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : <String, dynamic>{};
        final detail = body['detail'];
        String message;
        if (detail is List) {
          message = detail.map((e) => e['msg']?.toString() ?? '').join(', ');
        } else {
          message = detail?.toString() ?? "카카오 로그인 실패";
        }
        return {"success": false, "message": message};
      }
    } on KakaoException catch (e) {
      return {"success": false, "message": "카카오 로그인 실패: ${e.message ?? e.toString()}"};
    } catch (e) {
      return {"success": false, "message": "로그인 처리 중 오류가 발생했습니다."};
    }
  }

  /// 프로필 보완 (성별/생년월일) - 카카오 가입 후 비어있을 때 호출
  Future<Map<String, dynamic>> updateProfile(
    String birthdate,
    String gender,
  ) async {
    try {
      final token = await storage.read(key: 'jwt_token');
      if (token == null || token.isEmpty) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }
      final origin = await ApiConfig.getBaseOrigin();
      final response = await http.patch(
        Uri.parse('$origin/auth/me'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"birthdate": birthdate, "gender": gender}),
      );
      if (response.statusCode == 200) {
        return {"success": true};
      }
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      final detail = body['detail'];
      String message;
      if (detail is List) {
        message = detail.map((e) => e['msg'] ?? e.toString()).join(', ');
      } else {
        message = detail?.toString() ?? "프로필 업데이트 실패";
      }
      return {"success": false, "message": message};
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패"};
    }
  }
}