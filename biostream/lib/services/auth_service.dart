//백엔드와 통신을 담당할 파일
import 'dart:convert';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'api_config.dart';

class AuthService {
  final storage = const FlutterSecureStorage();

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
    try {
      final origin = await ApiConfig.getBaseOrigin();
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
        await storage.write(key: 'jwt_token', value: data['access_token']);
        return {"success": true, "nickname": data['nickname']};
      } else {
        return {"success": false, "message": "이메일 또는 비밀번호가 틀렸습니다."};
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패"};
    }
  }

  /// 카카오 로그인: 카카오 SDK로 인증 후 백엔드에 사용자 정보 전달
  Future<Map<String, dynamic>> loginWithKakao() async {
    try {
      // 1. 카카오 로그인 (카카오톡 또는 카카오계정)
      final talkInstalled = await isKakaoTalkInstalled();
      if (talkInstalled) {
        try {
          await UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          if (e is PlatformException && e.code == 'CANCELED') {
            return {"success": false, "message": "로그인이 취소되었습니다."};
          }
          await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        await UserApi.instance.loginWithKakaoAccount();
      }

      // 2. 카카오 사용자 정보 조회
      // 참고: 생년·생일·성별은 비즈앱에서만 동의 항목 활성화 가능.
      // 비즈앱 아닌 경우 생활습관 설문에서 선택 입력받아 사용.
      User user = await UserApi.instance.me();
      final kakaoId = user.id.toString();
      final email = user.kakaoAccount?.email ?? 'kakao_$kakaoId@kakao.user';
      final nickname =
          user.kakaoAccount?.profile?.nickname ?? '카카오사용자';

      // birthdate: YYYY-MM-DD (birthyear + birthday)
      String? birthdate;
      final year = user.kakaoAccount?.birthyear;
      final bday = user.kakaoAccount?.birthday;
      if (year != null && bday != null && bday.length == 4) {
        birthdate = '$year-${bday.substring(0, 2)}-${bday.substring(2)}';
      } else if (year != null) {
        birthdate = '$year-01-01';
      }

      // gender: male/female -> 남성/여성 (enum이면 .name, 문자열이면 그대로)
      String? gender;
      final g = user.kakaoAccount?.gender;
      if (g != null) {
        final gStr = g.toString().toLowerCase();
        if (gStr.contains('male')) {
          gender = '남성';
        } else if (gStr.contains('female')) {
          gender = '여성';
        } else {
          gender = '기타';
        }
      }

      // 3. 백엔드 카카오 로그인 API 호출
      final origin = await ApiConfig.getBaseOrigin();
      final body = {
        "kakao_id": kakaoId,
        "email": email,
        "nickname": nickname,
        if (birthdate != null) "birthdate": birthdate,
        if (gender != null) "gender": gender,
      };

      final response = await http.post(
        Uri.parse('$origin/auth/kakao-login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await storage.write(key: 'jwt_token', value: data['access_token']);
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