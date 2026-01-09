import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class LifestyleService {
  final storage = const FlutterSecureStorage();

  // 생활습관 설문 저장
  Future<Map<String, dynamic>> saveLifestyleProfile(Map<String, dynamic> data) async {
    try {
      final token = await storage.read(key: 'jwt_token');
      if (token == null) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await http.post(
        Uri.parse('$origin/api/lifestyle-profile'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return {"success": true, "message": "생활습관 정보가 저장되었습니다."};
      } else {
        final errorData = jsonDecode(response.body);
        return {"success": false, "message": errorData['detail'] ?? "저장에 실패했습니다."};
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }
}


