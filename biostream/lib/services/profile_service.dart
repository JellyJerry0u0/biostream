import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class ProfileService {
  static const _tokenKey = 'jwt_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await http.get(
        Uri.parse('$origin/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      }
      if (response.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        return {
          'success': false,
          'token_expired': true,
          'message': '로그인이 만료되었습니다. 다시 로그인해주세요.',
        };
      }

      final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      return {
        'success': false,
        'message': body is Map<String, dynamic>
            ? (body['detail'] ?? '프로필 조회 실패').toString()
            : '프로필 조회 실패',
      };
    } catch (e) {
      return {'success': false, 'message': '프로필 조회 중 오류가 발생했습니다.'};
    }
  }

  Future<Map<String, dynamic>> updateMyProfile({
    required String nickname,
    required String email,
    String? profileImagePath,
  }) async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final request =
          http.MultipartRequest('PUT', Uri.parse('$origin/auth/me'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['nickname'] = nickname;
      request.fields['email'] = email;

      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
            'profile_image', profileImagePath));
      }

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      }
      if (streamed.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        return {
          'success': false,
          'token_expired': true,
          'message': '로그인이 만료되었습니다. 다시 로그인해주세요.',
        };
      }

      final body = responseBody.isNotEmpty ? jsonDecode(responseBody) : null;
      return {
        'success': false,
        'message': body is Map<String, dynamic>
            ? (body['detail'] ?? '프로필 수정 실패').toString()
            : '프로필 수정 실패',
      };
    } catch (e) {
      return {'success': false, 'message': '프로필 수정 중 오류가 발생했습니다.'};
    }
  }
}
