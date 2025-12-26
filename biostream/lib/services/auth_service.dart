//백엔드와 통신을 담당할 파일
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // 안드로이드 에뮬레이터에서 로컬 백엔드 접속 시 10.0.2.2:8080 사용
  static const String baseUrl = "http://localhost:8080/auth";
  final storage = const FlutterSecureStorage();

  // 회원가입 요청
  Future<Map<String, dynamic>> signUp(String email, String password, String nickname) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "nickname": nickname,
        }),
      );
      return {"success": response.statusCode == 200, "message": jsonDecode(response.body)['detail'] ?? "회원가입 완료"};
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패"};
    }
  }

  // 로그인 요청 및 토큰 저장
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
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