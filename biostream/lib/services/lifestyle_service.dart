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

  // 생활습관 데이터 조회 (MCP tool 호출)
  Future<Map<String, dynamic>> getLifestyleData() async {
    try {
      final token = await storage.read(key: 'jwt_token');
      if (token == null) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await http.get(
        Uri.parse('$origin/data/lifestyle'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data['data']};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "데이터 조회에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  // 건강 리포트 생성 (LLM 호출, MCP tool 사용)
  Future<Map<String, dynamic>> generateHealthReport() async {
    try {
      final token = await storage.read(key: 'jwt_token');
      if (token == null) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await http.post(
        Uri.parse('$origin/data/generate-health-report'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "report": data['report'],
          "lifestyle_data": data['lifestyle_data'],  // Dart Map은 get() 메서드 없음
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "리포트 생성에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }
}


