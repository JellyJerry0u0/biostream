import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';
import 'authorized_http.dart';

class ProfileService {
  final AuthorizedHttp _http = AuthorizedHttp();
  final AuthService _auth = AuthService();

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(Uri.parse('$origin/auth/me'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      }
      if (response.statusCode == 401) {
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
    required String accountEmail,
    double? heightCm,
    double? weightKg,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();

      Future<http.StreamedResponse> sendMultipart() async {
        final token = await _auth.storage.read(key: 'jwt_token');
        final request =
            http.MultipartRequest('PUT', Uri.parse('$origin/auth/me'));
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        request.fields['nickname'] = nickname;
        request.fields['email'] = accountEmail;
        if (heightCm != null && heightCm > 0) {
          request.fields['height_cm'] = heightCm.toString();
        }
        if (weightKg != null && weightKg > 0) {
          request.fields['weight_kg'] = weightKg.toString();
        }

        return request.send();
      }

      var streamed = await sendMultipart();
      var responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode == 401) {
        if (await _auth.refreshTokens()) {
          streamed = await sendMultipart();
          responseBody = await streamed.stream.bytesToString();
        }
      }

      if (streamed.statusCode == 401) {
        await _auth.invalidateLocalSession();
        return {
          'success': false,
          'token_expired': true,
          'message': '로그인이 만료되었습니다. 다시 로그인해주세요.',
        };
      }

      if (streamed.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        return {'success': true, 'data': data};
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
