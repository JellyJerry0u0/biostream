import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Health Connect(Android) / HealthKit(iOS) 수면 데이터를 읽어
/// 평일·주말 평균 수면시간을 계산하는 서비스.
class SleepAutoFillService {
  /// iOS HealthKit에는 SLEEP_SESSION 이 없음 → ASLEEP 만 요청
  static List<HealthDataType> _sleepTypesForAuth() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return [HealthDataType.SLEEP_ASLEEP];
    }
    return [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_SESSION];
  }

  static const _daysToQuery = 7;

  /// 최근 7일 수면을 분석해 평일/주말 평균 시간(시간 단위) 반환.
  /// 데이터가 일부만 있어도 있는 기간으로 추정. 전혀 없으면 null.
  static Future<SleepAutoFillResult?> fetchSuggestedValues() async {
    if (kIsWeb) return null;

    try {
      final health = Health();
      await health.configure();

      final sleepTypes = _sleepTypesForAuth();
      final granted = await health.requestAuthorization(
        sleepTypes,
        permissions: List.filled(sleepTypes.length, HealthDataAccess.READ),
      );
      if (!granted) return null;

      final now = DateTime.now();
      final start = now.subtract(Duration(days: _daysToQuery));

      // SLEEP_ASLEEP 우선, 없으면 SLEEP_SESSION
      var points = await health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: start,
        endTime: now,
      );

      if (points.isEmpty && defaultTargetPlatform != TargetPlatform.iOS) {
        points = await health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_SESSION],
          startTime: start,
          endTime: now,
        );
      }

      if (points.isEmpty) return null;

      // 날짜별 수면 분 합산 (dateTo=기상 시각 기준으로 그룹 - 자정 넘는 수면 반영)
      final minutesByDate = <DateTime, int>{};

      for (final point in points) {
        final value = point.value;
        if (value is! NumericHealthValue) continue;

        final minutes = value.numericValue.toInt();
        if (minutes <= 0) continue;

        final date = DateTime(
          point.dateTo.year,
          point.dateTo.month,
          point.dateTo.day,
        );
        minutesByDate[date] = (minutesByDate[date] ?? 0) + minutes;
      }

      if (minutesByDate.isEmpty) return null;

      // 평일/주말 분리 - 있는 날짜의 데이터만 사용 (ex: 월6h, 수8h, 토9h → 평일7h, 주말9h)
      final weekdayMinutes = <int>[];
      final weekendMinutes = <int>[];

      for (final entry in minutesByDate.entries) {
        final dayMinutes = entry.value;
        final weekday = entry.key.weekday; // 1=Mon .. 7=Sun
        if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
          weekendMinutes.add(dayMinutes);
        } else {
          weekdayMinutes.add(dayMinutes);
        }
      }

      double? weekdayAvgHours;
      double? weekendAvgHours;

      // 있는 날짜로만 평균 계산 (없는 날은 포함하지 않음)
      if (weekdayMinutes.isNotEmpty) {
        final total = weekdayMinutes.reduce((a, b) => a + b);
        weekdayAvgHours = total / weekdayMinutes.length / 60.0;
      }
      if (weekendMinutes.isNotEmpty) {
        final total = weekendMinutes.reduce((a, b) => a + b);
        weekendAvgHours = total / weekendMinutes.length / 60.0;
      }

      if (weekdayAvgHours == null && weekendAvgHours == null) return null;
      // 한쪽만 있으면 그 값으로 양쪽 제안
      if (weekdayAvgHours == null) weekdayAvgHours = weekendAvgHours;
      if (weekendAvgHours == null) weekendAvgHours = weekdayAvgHours;

      // 3~10시간 범위로 클램프, 소수 1자리
      final clamp = (double v) => (v.clamp(3.0, 10.0) * 10).round() / 10.0;

      return SleepAutoFillResult(
        sleepHoursWeekday: clamp(weekdayAvgHours!),
        sleepHoursWeekend: clamp(weekendAvgHours!),
      );
    } catch (e) {
      debugPrint('[SleepAutoFillService] Error: $e');
      return null;
    }
  }
}

class SleepAutoFillResult {
  final double sleepHoursWeekday;
  final double sleepHoursWeekend;

  SleepAutoFillResult({
    required this.sleepHoursWeekday,
    required this.sleepHoursWeekend,
  });
}
