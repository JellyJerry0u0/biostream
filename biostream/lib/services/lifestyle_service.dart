import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      } else if (response.statusCode == 401) {
        // 토큰 만료 또는 유효하지 않은 토큰
        await storage.delete(key: 'jwt_token');
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
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
      } else if (response.statusCode == 401) {
        // 토큰 만료 또는 유효하지 않은 토큰
        await storage.delete(key: 'jwt_token');
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
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

  // 건강 리포트 생성 (순차 파이프라인 + RAG, MCP tool 사용)
  Future<Map<String, dynamic>> generateHealthReport(
    int lifestyleId, {
    bool force = false,
    String? situationText,
  }) async {
    try {
      final token = await storage.read(key: 'jwt_token');
      if (token == null) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final uri = force
          ? Uri.parse('$origin/api/generate-report/$lifestyleId?force=true')
          : Uri.parse('$origin/api/generate-report/$lifestyleId');

      final body = situationText != null && situationText.isNotEmpty
          ? jsonEncode({"situation_text": situationText})
          : '{}';
      debugPrint('[LifestyleService] generateHealthReport situationText 전달: ${situationText != null ? "있음 (${situationText.length}자)" : "없음"}, body: $body');

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "report": data['report'],
          "cards": data['cards'],
          "already_exists": data['already_exists'] ?? false,  // 이미 존재하는 리포트 플래그
          "message": data['message'],
        };
      } else if (response.statusCode == 401) {
        // 토큰 만료 또는 유효하지 않은 토큰
        await storage.delete(key: 'jwt_token');
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
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

  // 건강 리포트 조회
  Future<Map<String, dynamic>> getHealthReport(int lifestyleId) async {
    try {
      final token = await storage.read(key: 'jwt_token');
      if (token == null) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await http.get(
        Uri.parse('$origin/api/report/$lifestyleId'),
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
        };
      } else if (response.statusCode == 401) {
        // 토큰 만료 또는 유효하지 않은 토큰
        await storage.delete(key: 'jwt_token');
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "리포트 조회에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }
}


