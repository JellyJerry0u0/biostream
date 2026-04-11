import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/exercise_auto_fill_service.dart';
import '../../services/lifestyle_service.dart';
import '../../widgets/today_me/today_me_lifestyle_edit_dialogs.dart';
import 'today_me_models.dart';

class TodayMeMetricsLoadResult {
  const TodayMeMetricsLoadResult({
    this.items,
    this.notice,
    this.todayHistoryRow,
    this.hasTodayDailySnapshot = false,
    this.snapshotComplete = false,
  });

  final List<TodayLifestyleItem>? items;
  final String? notice;
  /// 오늘 날짜 기준 병합 값(히스토리 그래프에 당일 점으로 합침)
  final LifestyleHistoryDay? todayHistoryRow;
  /// 서버 `daily_lifestyle_snapshot` 에 오늘 날짜 행이 있는지
  final bool hasTodayDailySnapshot;
  /// 오늘 스냅샷 8영역이 모두 채워졌는지 (인트로·완료 팝업·대시보드)
  final bool snapshotComplete;
}

class TodayMeController {
  TodayMeController({required LifestyleService lifestyleService})
      : _lifestyleService = lifestyleService;

  final LifestyleService _lifestyleService;

  static const _cacheKey = 'today_lifestyle_cache';
  static const _cacheDateKey = 'today_lifestyle_cache_date';

  /// 오늘의 나의 생활 로드 — 체중·키는 미표시(설문·리포트 전용).
  /// 수면: 기기 건강 우선, 없으면 API(오늘 스냅샷·ChronoLens 동기화).
  /// 운동: 기기 건강 우선, 없으면 API 스냅샷만. 그 외 필드는 API 스냅샷만.
  Future<TodayMeMetricsLoadResult> loadTodayLifestyle() async {
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final apiResult = await _lifestyleService.getTodayLifestyle(forCalendarDate: dateStr);
    Map<String, dynamic> apiData = {};
    if (apiResult['success'] == true && apiResult['data'] != null) {
      apiData = Map<String, dynamic>.from(apiResult['data'] as Map);
    }
    final hasTodayDailySnapshot = apiData['hasDailySnapshot'] == true;
    final snapshotComplete = apiData['snapshotComplete'] == true;

    int? healthSleepMinutes;
    TodayExerciseResult? exerciseResult;

    if (!kIsWeb) {
      try {
        final health = Health();
        await health.configure();
        final sleepTypes = <HealthDataType>[
          HealthDataType.SLEEP_ASLEEP,
          if (defaultTargetPlatform != TargetPlatform.iOS)
            HealthDataType.SLEEP_SESSION,
        ];
        final granted = await health.requestAuthorization(
          sleepTypes,
          permissions: List.filled(sleepTypes.length, HealthDataAccess.READ),
        );
        if (granted) {
          final startOfDay = DateTime(today.year, today.month, today.day);

          final sleepPoints = await health.getHealthDataFromTypes(
            types: sleepTypes,
            startTime: startOfDay,
            endTime: today,
          );
          int sleepTotal = 0;
          for (final p in sleepPoints) {
            if (p.value is NumericHealthValue) {
              final nv = (p.value as NumericHealthValue).numericValue;
              sleepTotal += nv.toInt();
            }
          }
          if (sleepTotal > 0) {
            healthSleepMinutes = sleepTotal;
          } else if (defaultTargetPlatform != TargetPlatform.iOS) {
            final sleepSession = await health.getHealthDataFromTypes(
              types: const [HealthDataType.SLEEP_SESSION],
              startTime: startOfDay,
              endTime: today,
            );
            for (final p in sleepSession) {
              healthSleepMinutes =
                  (healthSleepMinutes ?? 0) +
                  p.dateTo.difference(p.dateFrom).inMinutes;
            }
          }
        }
      } catch (e) {
        debugPrint('[TodayMeController] Health read error: $e');
      }

      exerciseResult = await ExerciseAutoFillService.fetchTodaySessions();
    }

    int? apiSleepMinutes;
    final sm = apiData['sleepMinutes'];
    if (sm is num) {
      final v = sm.toInt();
      if (v > 0) apiSleepMinutes = v;
    }

    final int? sleepMin;
    if (healthSleepMinutes != null && healthSleepMinutes > 0) {
      sleepMin = healthSleepMinutes;
    } else {
      sleepMin = apiSleepMinutes;
    }
    final sleepFromHealth = sleepMin != null &&
        healthSleepMinutes != null &&
        healthSleepMinutes > 0 &&
        sleepMin == healthSleepMinutes;

    int? aerobic = exerciseResult?.aerobicSessions30min;
    int? resistance = exerciseResult?.resistanceSessions30min;
    final aerApi = apiData['aerobicSessions30min'];
    final resApi = apiData['resistanceSessions30min'];
    if (aerobic == null && aerApi is num) aerobic = aerApi.toInt();
    if (resistance == null && resApi is num) resistance = resApi.toInt();
    final exerciseFromHealth = exerciseResult != null;

    final exerciseLabel = (aerobic != null && resistance != null)
        ? '유산소 $aerobic회 / 근력 $resistance회'
        : '-';

    final drinkingRaw = apiData['drinkingDaysPerWeek']?.toString();
    final drinking = drinkingRaw ?? '-';
    final smoking = apiData['smokingStatus']?.toString() ?? '-';
    final stress = apiData['stressScore'] != null ? (apiData['stressScore'] as num).toDouble() : null;
    final sleepQuality = apiData['sleepQualityScore'] != null ? (apiData['sleepQualityScore'] as num).toDouble() : null;
    final uvOutdoor = apiData['uvOutdoor10to16']?.toString();
    final sunscreen = apiData['sunscreenApplied'] as bool?;

    final items = <TodayLifestyleItem>[
      TodayLifestyleItem(key: 'drinking', icon: Icons.local_bar, label: '음주', value: _drinkingBinaryLabel(drinkingRaw), unit: ''),
      TodayLifestyleItem(key: 'smoking', icon: Icons.smoking_rooms, label: '흡연', value: _smokingBinaryLabel(smoking), unit: ''),
      TodayLifestyleItem(key: 'stress', icon: Icons.psychology, label: '스트레스', value: stress != null ? '${stress.toInt()}/10' : '-', unit: ''),
      TodayLifestyleItem(
          key: 'sleep',
          icon: Icons.bedtime,
          label: '수면',
          value: (sleepMin != null && sleepMin > 0)
              ? '${(sleepMin / 60).toStringAsFixed(1)}시간'
              : '-',
          unit: ''),
      TodayLifestyleItem(key: 'sleep_quality', icon: Icons.bedtime_outlined, label: '수면의 질', value: sleepQuality != null ? '${sleepQuality.toInt()}/10' : '-', unit: ''),
      TodayLifestyleItem(key: 'uv_outdoor', icon: Icons.wb_sunny_outlined, label: '코어시간 외출', value: _uvOutdoorLabel(uvOutdoor), unit: ''),
      TodayLifestyleItem(key: 'sunscreen', icon: Icons.filter_drama_outlined, label: '선크림', value: sunscreen == true ? '도포' : (sunscreen == false ? '도포X' : '-'), unit: ''),
      TodayLifestyleItem(key: 'exercise', icon: Icons.fitness_center, label: '운동', value: exerciseLabel, unit: '30분+'),
    ];

    final cache = <String, dynamic>{
      'date': dateStr,
      'drinkingDaysPerWeek': drinkingRaw ?? (drinking == '-' ? null : drinking),
      'smokingStatus': smoking == '-' ? null : smoking,
      'stressScore': stress,
      'sleepMinutes': (sleepMin != null && sleepMin > 0) ? sleepMin : null,
      'sleepQualityScore': sleepQuality,
      'uvOutdoor10to16': uvOutdoor,
      'sunscreenApplied': sunscreen,
      if (aerobic != null) 'aerobicSessions30min': aerobic,
      if (resistance != null) 'resistanceSessions30min': resistance,
    };
    _persistCache(cache);

    final notice = _buildHealthDataNotice(
      sleepFromHealth: sleepFromHealth,
      exerciseFromHealth: exerciseFromHealth,
    );

    final todayHistoryRow = LifestyleHistoryDay(
      date: DateTime(today.year, today.month, today.day),
      drinkingDaysPerWeek:
          drinkingRaw ?? (drinking == '-' ? null : drinking),
      smokingStatus: smoking == '-' ? null : smoking,
      stressScore: stress,
      sleepMinutes: sleepMin,
      sleepQualityScore: sleepQuality,
      aerobicSessions30min: aerobic,
      resistanceSessions30min: resistance,
      uvOutdoor10to16: uvOutdoor,
      sunscreenApplied: sunscreen,
    );

    return TodayMeMetricsLoadResult(
      items: items,
      notice: notice,
      todayHistoryRow: todayHistoryRow,
      hasTodayDailySnapshot: hasTodayDailySnapshot,
      snapshotComplete: snapshotComplete,
    );
  }

  /// 히스토리 행 → 카드 표시용 (백데이트 입력·시트 초기값)
  List<TodayLifestyleItem> itemsFromHistoryDay(LifestyleHistoryDay? h) {
    final drinkingRaw = h?.drinkingDaysPerWeek;
    final smokingRaw = h?.smokingStatus ?? '-';
    final stress = h?.stressScore;
    final sleepMin = h?.sleepMinutes;
    final sleepQuality = h?.sleepQualityScore;
    final uvOutdoor = h?.uvOutdoor10to16;
    final sunscreen = h?.sunscreenApplied;
    final aerobic = h?.aerobicSessions30min;
    final resistance = h?.resistanceSessions30min;

    final exerciseLabel = (aerobic != null && resistance != null)
        ? '유산소 $aerobic회 / 근력 $resistance회'
        : '-';

    return [
      TodayLifestyleItem(
        key: 'drinking',
        icon: Icons.local_bar,
        label: '음주',
        value: _drinkingBinaryLabel(drinkingRaw),
        unit: '',
      ),
      TodayLifestyleItem(
        key: 'smoking',
        icon: Icons.smoking_rooms,
        label: '흡연',
        value: _smokingBinaryLabel(smokingRaw),
        unit: '',
      ),
      TodayLifestyleItem(
        key: 'stress',
        icon: Icons.psychology,
        label: '스트레스',
        value: stress != null ? '${stress.toInt()}/10' : '-',
        unit: '',
      ),
      TodayLifestyleItem(
        key: 'sleep',
        icon: Icons.bedtime,
        label: '수면',
        value: (sleepMin != null && sleepMin > 0)
            ? '${(sleepMin / 60).toStringAsFixed(1)}시간'
            : '-',
        unit: '',
      ),
      TodayLifestyleItem(
        key: 'sleep_quality',
        icon: Icons.bedtime_outlined,
        label: '수면의 질',
        value: sleepQuality != null ? '${sleepQuality.toInt()}/10' : '-',
        unit: '/10',
      ),
      TodayLifestyleItem(
        key: 'uv_outdoor',
        icon: Icons.wb_sunny_outlined,
        label: '코어시간 외출',
        value: _uvOutdoorLabel(uvOutdoor),
        unit: '',
      ),
      TodayLifestyleItem(
        key: 'sunscreen',
        icon: Icons.filter_drama_outlined,
        label: '선크림',
        value: sunscreen == true
            ? '도포'
            : (sunscreen == false ? '도포X' : '-'),
        unit: '',
      ),
      TodayLifestyleItem(
        key: 'exercise',
        icon: Icons.fitness_center,
        label: '운동',
        value: exerciseLabel,
        unit: '30분+',
      ),
    ];
  }

  /// 최근 일별 스냅샷 시계열 (서버)
  Future<List<LifestyleHistoryDay>> loadLifestyleHistory({int days = 14}) async {
    final r = await _lifestyleService.getDailyLifestyleHistory(days: days);
    if (r['success'] != true) return [];
    final data = r['data'];
    if (data is! Map<String, dynamic>) return [];
    final items = data['items'];
    if (items is! List) return [];
    final out = <LifestyleHistoryDay>[];
    for (final e in items) {
      if (e is Map<String, dynamic>) {
        out.add(LifestyleHistoryDay.fromJson(e));
      } else if (e is Map) {
        out.add(LifestyleHistoryDay.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  }

  /// 설문 화면과 동일 톤: 기기 건강 데이터로 채운 항목 안내
  String? _buildHealthDataNotice({
    required bool sleepFromHealth,
    required bool exerciseFromHealth,
  }) {
    if (!sleepFromHealth && !exerciseFromHealth) return null;
    if (sleepFromHealth && exerciseFromHealth) {
      return '수면·운동은 건강 데이터에서 가져왔습니다.';
    }
    if (sleepFromHealth) return '수면은 건강 데이터에서 가져왔습니다.';
    return '운동은 건강 데이터에서 가져왔습니다.';
  }

  /// 오늘의 나 표시용: 음주 / 금주 (API `drinkingDaysPerWeek` 기준)
  String _drinkingBinaryLabel(String? raw) {
    if (raw == null || raw.isEmpty || raw == '-') return '-';
    final s = raw.trim();
    if (s == '0') return '금주';
    return '음주';
  }

  /// 오늘의 나 표시용: 흡연 / 금연
  String _smokingBinaryLabel(String v) {
    if (v == '-' || v.isEmpty) return '-';
    final low = v.toLowerCase();
    if (low.contains('current') || v.contains('현재')) return '흡연';
    return '금연';
  }

  String _uvOutdoorLabel(String? v) {
    if (v == null || v.isEmpty) return '-';
    const labels = {'<30m': '30분 미만', '30~60': '30분~1시간', '1~2h': '1~2시간', '>2h': '2시간 이상'};
    return labels[v] ?? v;
  }

  /// 편집 다이얼로그 「완료」 결과 → 카드 표시 문자열 (서버 저장 전 로컬 반영용)
  String displayValueForEditResult(String key, dynamic raw) {
    switch (key) {
      case 'drinking':
        return _drinkingBinaryLabel(raw?.toString());
      case 'smoking':
        return _smokingBinaryLabel(raw?.toString() ?? '');
      case 'stress':
        final v = raw is double ? raw : double.tryParse('$raw');
        if (v == null) return '-';
        return '${v.round()}/10';
      case 'sleep':
        final m = raw is int ? raw : int.tryParse('$raw') ?? 0;
        if (m <= 0) return '-';
        return '${(m / 60).toStringAsFixed(1)}시간';
      case 'sleep_quality':
        final v = raw is double ? raw : double.tryParse('$raw');
        if (v == null) return '-';
        return '${v.round()}/10';
      case 'uv_outdoor':
        return _uvOutdoorLabel(raw?.toString());
      case 'sunscreen':
        if (raw is bool) {
          return raw ? '도포' : '도포X';
        }
        return '-';
      case 'exercise':
        if (raw is Map) {
          final a = (raw['aerobic'] as num?)?.toInt() ?? 0;
          final r = (raw['resistance'] as num?)?.toInt() ?? 0;
          return '유산소 $a회 / 근력 $r회';
        }
        return '-';
      default:
        return '-';
    }
  }

  int? _sleepMinutesFromDisplay(String value) {
    if (value == '-' || value.isEmpty || !value.contains('시간')) return null;
    final t = value.replaceAll('시간', '').trim().replaceAll(',', '.');
    final h = double.tryParse(t);
    if (h == null || h <= 0) return null;
    return (h * 60).round();
  }

  double? _scoreFromDisplay(String value) {
    if (value == '-' || value.isEmpty) return null;
    final m = RegExp(r'^(\d+)').firstMatch(value.trim());
    if (m != null) return double.tryParse(m.group(1)!);
    return null;
  }

  bool? _sunscreenFromDisplay(String value) {
    if (value == '도포' || value == '도포함') return true;
    if (value == '도포X' || value == '안 함') return false;
    return null;
  }

  /// 현재 카드 표시값을 한 번에 서버 스냅샷으로 저장
  Future<Map<String, dynamic>> saveSnapshotBatchFromItems({
    required String date,
    required List<TodayLifestyleItem> items,
  }) async {
    String? drinkingDaysPerWeek;
    String? smokingStatus;
    double? stressScore;
    int? sleepMinutes;
    double? sleepQualityScore;
    int? aerobicSessions30min;
    int? resistanceSessions30min;
    String? uvOutdoor10to16;
    bool? sunscreenApplied;

    for (final item in items) {
      switch (item.key) {
        case 'drinking':
          final v = drinkingInitialApiValue(item.value);
          if (v != null) drinkingDaysPerWeek = v;
          break;
        case 'smoking':
          final v = smokingInitialApiValue(item.value);
          if (v != null) smokingStatus = v;
          break;
        case 'stress':
          final v = _scoreFromDisplay(item.value);
          if (v != null) stressScore = v;
          break;
        case 'sleep':
          final v = _sleepMinutesFromDisplay(item.value);
          if (v != null) sleepMinutes = v;
          break;
        case 'sleep_quality':
          final v = _scoreFromDisplay(item.value);
          if (v != null) sleepQualityScore = v;
          break;
        case 'uv_outdoor':
          final k = uvKeyFromItemDisplay(item.value);
          if (k != null) uvOutdoor10to16 = k;
          break;
        case 'sunscreen':
          final b = _sunscreenFromDisplay(item.value);
          if (b != null) sunscreenApplied = b;
          break;
        case 'exercise':
          if (item.value != '-' && item.value.trim().isNotEmpty) {
            final p = parseTodayMeExerciseInitial(item.value);
            aerobicSessions30min = p.aerobic;
            resistanceSessions30min = p.resistance;
          }
          break;
      }
    }

    return _lifestyleService.saveDailyLifestyleSnapshot(
      date: date,
      drinkingDaysPerWeek: drinkingDaysPerWeek,
      smokingStatus: smokingStatus,
      stressScore: stressScore,
      sleepMinutes: sleepMinutes,
      sleepQualityScore: sleepQualityScore,
      aerobicSessions30min: aerobicSessions30min,
      resistanceSessions30min: resistanceSessions30min,
      uvOutdoor10to16: uvOutdoor10to16,
      sunscreenApplied: sunscreenApplied,
    );
  }

  Future<void> _persistCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
      await prefs.setString(_cacheDateKey, data['date']?.toString() ?? '');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getCachedForMidnightSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = prefs.getString(_cacheKey);
      if (cache == null) return {};
      final data = jsonDecode(cache) as Map<String, dynamic>;
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return {};
    }
  }

  /// 항목 저장 (편집 시)
  Future<Map<String, dynamic>> saveItem(String key, dynamic value, String dateStr) async {
    double? s, sleepQuality;
    int? sleep, aer, res;
    String? drinking, smoking, uvOutdoor;
    bool? sunscreen;

    switch (key) {
      case 'drinking':
        drinking = value?.toString();
        break;
      case 'smoking':
        smoking = value?.toString();
        break;
      case 'stress':
        s = value is double ? value : double.tryParse(value.toString());
        break;
      case 'sleep':
        sleep = value is int ? value : int.tryParse(value.toString());
        break;
      case 'sleep_quality':
        sleepQuality = value is double ? value : double.tryParse(value.toString());
        break;
      case 'uv_outdoor':
        uvOutdoor = value?.toString();
        break;
      case 'sunscreen':
        sunscreen = value is bool ? value : (value == true || value.toString() == 'true');
        break;
      case 'exercise':
        if (value is Map) {
          aer = value['aerobic'] as int?;
          res = value['resistance'] as int?;
        }
        break;
    }

    return _lifestyleService.saveDailyLifestyleSnapshot(
      date: dateStr,
      drinkingDaysPerWeek: drinking,
      smokingStatus: smoking,
      stressScore: s,
      sleepMinutes: sleep,
      sleepQualityScore: sleepQuality,
      aerobicSessions30min: aer,
      resistanceSessions30min: res,
      uvOutdoor10to16: uvOutdoor,
      sunscreenApplied: sunscreen,
    );
  }
}
