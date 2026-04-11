import 'dart:convert';

import 'api_config.dart';
import 'authorized_http.dart';

/// 스냅샷 최초 저장 등 서버가 쌓아 둔 코치 인앱 메시지
class CoachInboxService {
  CoachInboxService._();
  static final CoachInboxService instance = CoachInboxService._();

  final AuthorizedHttp _http = AuthorizedHttp();

  /// 조회만 (소비 안 함). 표시 후 [consumePendingNudge] 호출.
  Future<CoachPendingNudge?> peekPendingNudge() async {
    try {
      if (!await _http.hasAnyCredential()) return null;
      final origin = await ApiConfig.getBaseOrigin();
      final res = await _http.get(
        Uri.parse('$origin/api/coach/pending-nudge'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['has_pending'] != true) return null;
      final body = data['body']?.toString();
      if (body == null || body.isEmpty) return null;
      final id = (data['nudge_id'] as num?)?.toInt() ?? 0;
      return CoachPendingNudge(nudgeId: id, body: body);
    } catch (_) {
      return null;
    }
  }

  Future<bool> consumePendingNudge() async {
    try {
      if (!await _http.hasAnyCredential()) return false;
      final origin = await ApiConfig.getBaseOrigin();
      final res = await _http.post(
        Uri.parse('$origin/api/coach/pending-nudge/consume'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

class CoachPendingNudge {
  const CoachPendingNudge({required this.nudgeId, required this.body});

  final int nudgeId;
  final String body;
}
