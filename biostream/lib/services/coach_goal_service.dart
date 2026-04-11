import 'dart:convert';

import 'api_config.dart';
import 'authorized_http.dart';

/// 코치 적응형 목표 동의 API
class CoachGoalService {
  final AuthorizedHttp _http = AuthorizedHttp();

  Future<Map<String, dynamic>> submitConsent({
    required String sessionId,
    required String goalId,
    required bool accept,
    String? revisedTarget,
  }) async {
    if (!await _http.hasAnyCredential()) {
      return {'success': false, 'error': '로그인이 필요합니다.'};
    }
    final origin = await ApiConfig.getBaseOrigin();
    final uri = Uri.parse('$origin/api/coach/goals/consent');
    final body = <String, dynamic>{
      'session_id': sessionId,
      'goal_id': goalId,
      'accept': accept,
      if (revisedTarget != null && revisedTarget.isNotEmpty)
        'revised_target': revisedTarget,
    };
    final response = await _http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, ...data};
    }
    final detail = data['detail'];
    final msg = detail is String
        ? detail
        : (detail is List && detail.isNotEmpty)
            ? '${detail.first}'
            : '요청 실패 (${response.statusCode})';
    return {'success': false, 'error': msg};
  }
}
