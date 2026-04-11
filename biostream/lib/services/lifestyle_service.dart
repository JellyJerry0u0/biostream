import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_config.dart';
import 'authorized_http.dart';
import 'notification_service.dart';

class LifestyleService {
  final _http = AuthorizedHttp();

  // 생활습관 설문 저장
  Future<Map<String, dynamic>> saveLifestyleProfile(
      Map<String, dynamic> data) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/api/lifestyle-profile'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return {"success": true, "message": "생활습관 정보가 저장되었습니다."};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "저장에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  // 생활습관 데이터 조회 (MCP tool 호출)
  Future<Map<String, dynamic>> getLifestyleData() async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/data/lifestyle'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data['data']};
      } else if (response.statusCode == 401) {
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
  /// [skipImage] true면 이미지 생성 생략 (응답 5~30초 단축, 이미지는 별도 처리 필요)
  Future<Map<String, dynamic>> generateHealthReport(
    int lifestyleId, {
    bool force = false,
    bool skipImage = false,
    String? situationText,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      // 리포트 생성 직전에 FCM 토큰 동기화를 강제하여 즉시 푸시 대상을 보장
      await NotificationService.instance.syncTokenToServer();

      final origin = await ApiConfig.getBaseOrigin();
      final queryParams = <String, String>{};
      if (force) queryParams['force'] = 'true';
      if (skipImage) queryParams['skip_image'] = 'true';
      final uri = Uri.parse('$origin/api/generate-report/$lifestyleId')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final body = situationText != null && situationText.isNotEmpty
          ? jsonEncode({"situation_text": situationText})
          : '{}';
      debugPrint(
          '[LifestyleService] generateHealthReport situationText 전달: ${situationText != null ? "있음 (${situationText.length}자)" : "없음"}, body: $body');

      final response = await _http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "report": data['report'],
          "cards": data['cards'],
          "already_exists": data['already_exists'] ?? false, // 이미 존재하는 리포트 플래그
          "message": data['message'],
        };
      } else if (response.statusCode == 401) {
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

  Future<Map<String, dynamic>> requestGenerateDefault(int lifestyleId) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/data/generate/$lifestyleId'),
        headers: {
          "Content-Type": "application/json",
        },
        body: '{}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          '[LifestyleService] /data/generate OK — params=${data['params']} '
          'gpu_request=${data['params']?['gpu_request']}',
        );
        return {"success": true, "data": data};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "기본 이미지 생성 요청에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  Future<Map<String, dynamic>> requestSkinEdit({
    required int lifestyleId,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/data/skin-edit/$lifestyleId'),
        headers: {
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          '[LifestyleService] /data/skin-edit OK — skin_edit_trace=${data['skin_edit_trace']} '
          'params=${data['params']} gpu_request=${data['params']?['gpu_request']}',
        );
        return {"success": true, "data": data};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "skin-edit 요청에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  // 건강 리포트 조회
  Future<Map<String, dynamic>> getHealthReport(int lifestyleId) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/api/report/$lifestyleId'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          "success": true,
          "report": data['report'],
          "lifestyle_data": data['lifestyle_data'],
          "notion_url": data['notion_url'],
          "cards": data['cards'],
        };
      } else if (response.statusCode == 401) {
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

  Future<Map<String, dynamic>> saveGeneratedReport({
    required int lifestyleId,
    required Map<String, dynamic> report,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/api/report/$lifestyleId/save'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({"report": report}),
      );

      if (response.statusCode == 200) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "리포트 저장에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  Future<Map<String, dynamic>> getYesterdayHealthData() async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/api/v1/yesterday-health'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "어제 건강 데이터 조회에 실패했습니다.",
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  /// 최근 7일 건강 데이터 집계 (운동 설문 자동채우기용)
  Future<Map<String, dynamic>> getRecentHealthSummary({int days = 7}) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/api/v1/recent-health-summary?days=$days'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로드해주세요.",
          "token_expired": true,
        };
      } else {
        final err = jsonDecode(response.body);
        return {"success": false, "message": err['detail'] ?? "최근 건강 데이터 조회에 실패했습니다."};
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  /// 오늘의 나의 생활 조회 (체중/키/음주/흡연/스트레스/수면/운동)
  /// [forCalendarDate] YYYY-MM-DD — 저장 API와 같은 기기 달력일(도커 UTC 서버와 하루 어긋남 방지)
  Future<Map<String, dynamic>> getTodayLifestyle({String? forCalendarDate}) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final q = (forCalendarDate != null && forCalendarDate.trim().isNotEmpty)
          ? '?date=${Uri.encodeQueryComponent(forCalendarDate.trim())}'
          : '';
      final response = await _http.get(
        Uri.parse('$origin/api/v1/today-lifestyle$q'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final err = jsonDecode(response.body);
        return {"success": false, "message": err['detail'] ?? "오늘의 생활 데이터 조회에 실패했습니다."};
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  /// 최근 일별 생활 스냅샷 시계열 (그래프용)
  Future<Map<String, dynamic>> getDailyLifestyleHistory({int days = 14}) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/api/v1/daily-lifestyle-history?days=$days'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로드해주세요.",
          "token_expired": true,
        };
      } else {
        final err = jsonDecode(response.body);
        return {
          "success": false,
          "message": err['detail'] ?? "생활 기록 조회에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  /// 오늘의 나의 생활 스냅샷 저장 (자정 자동 저장용)
  Future<Map<String, dynamic>> saveDailyLifestyleSnapshot({
    required String date,
    String? drinkingDaysPerWeek,
    String? smokingStatus,
    double? stressScore,
    int? sleepMinutes,
    double? sleepQualityScore,
    int? aerobicSessions30min,
    int? resistanceSessions30min,
    String? uvOutdoor10to16,
    bool? sunscreenApplied,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final body = <String, dynamic>{"date": date};
      if (drinkingDaysPerWeek != null) body['drinkingDaysPerWeek'] = drinkingDaysPerWeek;
      if (smokingStatus != null) body['smokingStatus'] = smokingStatus;
      if (stressScore != null) body['stressScore'] = stressScore;
      if (sleepMinutes != null) body['sleepMinutes'] = sleepMinutes;
      if (sleepQualityScore != null) body['sleepQualityScore'] = sleepQualityScore;
      if (aerobicSessions30min != null) body['aerobicSessions30min'] = aerobicSessions30min;
      if (resistanceSessions30min != null) body['resistanceSessions30min'] = resistanceSessions30min;
      if (uvOutdoor10to16 != null) body['uvOutdoor10to16'] = uvOutdoor10to16;
      if (sunscreenApplied != null) body['sunscreenApplied'] = sunscreenApplied;

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/api/v1/daily-lifestyle-snapshot'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        return {
          "success": true,
          "message": data?['message']?.toString() ?? "저장되었습니다.",
          if (data?['first_daily_snapshot_today'] == true)
            'first_daily_snapshot_today': true,
        };
      } else if (response.statusCode == 401) {
        return {"success": false, "message": "로그인이 만료되었습니다.", "token_expired": true};
      } else {
        final err = jsonDecode(response.body);
        return {"success": false, "message": err['detail'] ?? "저장에 실패했습니다."};
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  Future<Map<String, dynamic>> getTodayHealthData() async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/api/v1/today-health'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "오늘 건강 데이터 조회에 실패했습니다.",
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  Future<Map<String, dynamic>> submitOutdoorCheckResponse({
    required String date,
    required String answer,
    int stepsSnapshot = 0,
  }) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final normalized = answer.trim().toLowerCase();
      if (normalized != 'yes' &&
          normalized != 'no' &&
          normalized != 'unknown') {
        return {"success": false, "message": "응답 값은 yes/no/unknown 이어야 합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.post(
        Uri.parse('$origin/api/v1/outdoor-check-response'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "date": date,
          "answer": normalized,
          "stepsSnapshot": stepsSnapshot,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"success": true, "data": data};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "야외 활동 응답 저장에 실패했습니다.",
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  Future<Map<String, dynamic>> getReportArchives() async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/api/report-archives'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "items": data['items'] ?? <dynamic>[],
          "total_count": data['total_count'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "아카이브 조회에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  Future<Map<String, dynamic>> getReportHistory() async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/api/report-history'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "items": data['items'] ?? <dynamic>[],
          "total_count": data['total_count'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "리포트 이력 조회에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  Future<Map<String, dynamic>> getLatestFutureFace() async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.get(
        Uri.parse('$origin/api/report-latest-future-face'),
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "최근 리포트 이미지 조회에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }

  Future<Map<String, dynamic>> updateQuestProgress(
    int lifestyleId,
    List<String> completedActionIds,
  ) async {
    try {
      if (!await _http.hasAnyCredential()) {
        return {"success": false, "message": "로그인이 필요합니다."};
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _http.patch(
        Uri.parse('$origin/api/report/$lifestyleId/quest-progress'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "completed_action_ids": completedActionIds,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "message": data['message'] ?? '생활습관 진행 상황이 저장되었습니다.',
        };
      } else if (response.statusCode == 401) {
        return {
          "success": false,
          "message": "로그인이 만료되었습니다. 다시 로그인해주세요.",
          "token_expired": true,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          "success": false,
          "message": errorData['detail'] ?? "생활습관 저장에 실패했습니다."
        };
      }
    } catch (e) {
      return {"success": false, "message": "서버 연결 실패: $e"};
    }
  }
}
