//백엔드와 통신을 담당할 파일
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  ) async {
    try {
      final origin = await ApiConfig.getBaseOrigin();
      final body = {
        "email": email,
        "password": password,
        "nickname": nickname,
        "birthdate": birthdate,
        "gender": gender,
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
}