import 'dart:convert';
import 'api_config.dart';
import 'authorized_http.dart';

class HabitService {
  final _http = AuthorizedHttp();

  /// 액션에서 '할게요' 선택 시 습관 추가
  Future<Map<String, dynamic>> commitAction({
    required int lifestyleId,
    required String sectionKey,
    required String actionTitle,
    String? actionDetail,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/api/committed-actions'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'lifestyle_id': lifestyleId,
          'section_key': sectionKey,
          'action_title': actionTitle,
          if (actionDetail != null && actionDetail.isNotEmpty) 'action_detail': actionDetail,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': '로그인이 만료되었습니다.', 'token_expired': true};
      }
      final err = _decodeErrorBody(response.body);
      final detail = err['detail'];
      final msg = detail is String
          ? detail
          : (detail is List && detail.isNotEmpty)
              ? detail.first.toString()
              : '생활습관 저장에 실패했습니다.';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  static Map<String, dynamic> _decodeErrorBody(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return {};
  }

  /// 내 습관 목록
  Future<Map<String, dynamic>> getCommittedActions({int? lifestyleId}) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();
      var uri = Uri.parse('$origin/api/committed-actions');
      if (lifestyleId != null) {
        uri = uri.replace(queryParameters: {'lifestyle_id': lifestyleId.toString()});
      }

      final response = await _http.get(uri, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': '로그인이 만료되었습니다.', 'token_expired': true};
      }
      return {'success': false, 'message': '습관 목록을 불러오지 못했습니다.'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  /// 개인화 수락 시 생활습관 제목/설명 업데이트
  Future<Map<String, dynamic>> updateCommittedAction({
    required int committedActionId,
    required String actionTitle,
    String? actionDetail,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }
      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.patch(
        Uri.parse('$origin/api/committed-actions/$committedActionId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action_title': actionTitle,
          if (actionDetail != null && actionDetail.isNotEmpty) 'action_detail': actionDetail,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': '로그인이 만료되었습니다.', 'token_expired': true};
      }
      final err = _decodeErrorBody(response.body);
      return {'success': false, 'message': err['detail']?.toString() ?? '업데이트에 실패했습니다.'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  /// 개인화 재생성 요청 (거절 후 1회)
  Future<Map<String, dynamic>> personalizeCommittedAction({
    required int committedActionId,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }
      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/api/committed-actions/$committedActionId/personalize'),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': '로그인이 만료되었습니다.', 'token_expired': true};
      }
      return {'success': false, 'message': '재생성에 실패했습니다.'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  /// 저장된 생활습관 제거(슬롯 비움)
  Future<Map<String, dynamic>> retireCommittedAction({
    required int committedActionId,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/api/committed-actions/$committedActionId/retire'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': '로그인이 만료되었습니다.', 'token_expired': true};
      }
      final err = _decodeErrorBody(response.body);
      final detail = err['detail'];
      final msg = detail is String
          ? detail
          : (detail is List && detail.isNotEmpty)
              ? detail.first.toString()
              : '생활습관을 삭제하지 못했습니다.';
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  /// 일별 체크인
  Future<Map<String, dynamic>> checkIn({
    required int committedActionId,
    required String checkDate,
    required bool completed,
    String? note,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/api/committed-actions/$committedActionId/check-in'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'check_date': checkDate,
          'completed': completed,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': '로그인이 만료되었습니다.', 'token_expired': true};
      }
      final err = jsonDecode(response.body);
      return {'success': false, 'message': err['detail'] ?? '체크인에 실패했습니다.'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

  /// 시계열/캘린더용 전체 체크인 요약
  Future<Map<String, dynamic>> getCheckInsSummary({
    String? fromDate,
    String? toDate,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final params = <String, String>{};
      if (fromDate != null) params['from_date'] = fromDate;
      if (toDate != null) params['to_date'] = toDate;
      final uri = Uri.parse('$origin/api/committed-actions/check-ins/summary')
          .replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await _http.get(uri, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        return {'success': false, 'message': '로그인이 만료되었습니다.', 'token_expired': true};
      }
      return {'success': false, 'message': '데이터를 불러오지 못했습니다.'};
    } catch (e) {
      return {'success': false, 'message': '서버 연결 실패: $e'};
    }
  }

}
