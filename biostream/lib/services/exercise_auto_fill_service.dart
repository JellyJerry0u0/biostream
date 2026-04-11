import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Health Connect(Android) / HealthKit(iOS) 운동 세션·걸음·거리를 읽어
/// 유산소·근력 주당 횟수를 계산하고 설문 값으로 매핑하는 서비스.
class ExerciseAutoFillService {
  static const _workoutTypes = [HealthDataType.WORKOUT];
  static const _activityTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.EXERCISE_TIME, // Apple Activity 링 '운동' 분
  ];
  static const _daysToQuery = 7;

  /// 최근 7일 운동·걸음·거리를 분석해 설문용 aerobic_weekly, resistance_weekly 추천값 반환.
  /// 권한 거부·에러 시 null 반환.
  static Future<ExerciseAutoFillResult?> fetchSuggestedValues() async {
    if (kIsWeb) return null;

    try {
      final health = Health();
      await health.configure();

      final allTypes = [..._workoutTypes, ..._activityTypes];
      final granted = await health.requestAuthorization(
        allTypes,
        permissions: List.filled(allTypes.length, HealthDataAccess.READ),
      );
      if (!granted) return null;

      final now = DateTime.now();
      final start = now.subtract(Duration(days: _daysToQuery));

      int aerobicMinutes = 0;
      int resistanceMinutes = 0;
      int aerobicSessions = 0;
      int resistanceSessions = 0;

      // 1) WORKOUT 세션
      final workoutPoints = await health.getHealthDataFromTypes(
        types: _workoutTypes,
        startTime: start,
        endTime: now,
      );
      for (final point in workoutPoints) {
        final value = point.value;
        if (value is! WorkoutHealthValue) continue;

        final durationMinutes = point.dateTo.difference(point.dateFrom).inMinutes;
        final effectiveMinutes = durationMinutes > 0 ? durationMinutes : 30;

        final type = value.workoutActivityType;
        if (_isResistanceType(type)) {
          resistanceMinutes += effectiveMinutes;
          if (durationMinutes <= 0) resistanceSessions += 1;
        } else if (_isAerobicType(type)) {
          aerobicMinutes += effectiveMinutes;
          if (durationMinutes <= 0) aerobicSessions += 1;
        } else {
          aerobicMinutes += effectiveMinutes;
          if (durationMinutes <= 0) aerobicSessions += 1;
        }
      }

      // 2) 걸음·거리·운동시간 (WORKOUT 없을 때 활동량 반영)
      if (aerobicMinutes == 0) {
        final activityPoints = await health.getHealthDataFromTypes(
          types: _activityTypes,
          startTime: start,
          endTime: now,
        );
        int totalSteps = 0;
        double totalDistanceM = 0;
        int exerciseTimeMin = 0;

        for (final point in activityPoints) {
          final v = point.value;
          if (v is NumericHealthValue) {
            if (point.type == HealthDataType.STEPS) {
              totalSteps += v.numericValue.toInt();
            } else if (point.type == HealthDataType.DISTANCE_WALKING_RUNNING) {
              totalDistanceM += v.numericValue;
            } else if (point.type == HealthDataType.EXERCISE_TIME) {
              exerciseTimeMin += v.numericValue.toInt();
            }
          }
        }

        // Apple 운동 시간(분) 직접 사용
        if (exerciseTimeMin > 0) {
          aerobicMinutes = exerciseTimeMin;
        } else {
          // 걸음·거리 (동일 활동 중복 방지 → 더 큰 값 사용)
          final stepsSessions = totalSteps ~/ 5000; // 5000보≈30분
          final distanceSessions = (totalDistanceM / 2000).floor(); // 2km≈30분
          final sessions = stepsSessions > distanceSessions ? stepsSessions : distanceSessions;
          aerobicMinutes = sessions * 30;
          if (aerobicMinutes == 0 && (totalSteps >= 2000 || totalDistanceM >= 800)) {
            aerobicMinutes = 30; // 1.2km·2000보 등 의미 있는 활동 → 최소 1회
          }
        }
      }

      final aerobicCount = (aerobicMinutes ~/ 30).clamp(aerobicSessions, 100);
      final resistanceCount = (resistanceMinutes ~/ 30).clamp(resistanceSessions, 100);

      return ExerciseAutoFillResult(
        aerobicWeekly: _mapAerobicToSurvey(aerobicCount),
        resistanceWeekly: _mapResistanceToSurvey(resistanceCount),
        aerobicCount: aerobicCount,
        resistanceCount: resistanceCount,
      );
    } catch (e) {
      debugPrint('[ExerciseAutoFillService] Error: $e');
      return null;
    }
  }

  static bool _isResistanceType(HealthWorkoutActivityType type) {
    const resistance = {
      HealthWorkoutActivityType.STRENGTH_TRAINING,
      HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
      HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
      HealthWorkoutActivityType.WEIGHTLIFTING,
      HealthWorkoutActivityType.CORE_TRAINING,
      HealthWorkoutActivityType.CALISTHENICS, // 맨몸 근력 (스쿼트, 푸시업 등)
      HealthWorkoutActivityType.BARRE, // 발레 바 근력
      HealthWorkoutActivityType.ROCK_CLIMBING,
      HealthWorkoutActivityType.CLIMBING,
      HealthWorkoutActivityType.WRESTLING,
      HealthWorkoutActivityType.MARTIAL_ARTS,
      HealthWorkoutActivityType.GYMNASTICS,
    };
    return resistance.contains(type);
  }

  static bool _isAerobicType(HealthWorkoutActivityType type) {
    const aerobic = {
      HealthWorkoutActivityType.RUNNING,
      HealthWorkoutActivityType.RUNNING_TREADMILL,
      HealthWorkoutActivityType.WALKING,
      HealthWorkoutActivityType.WALKING_TREADMILL,
      HealthWorkoutActivityType.BIKING,
      HealthWorkoutActivityType.BIKING_STATIONARY,
      HealthWorkoutActivityType.ELLIPTICAL,
      HealthWorkoutActivityType.ROWING,
      HealthWorkoutActivityType.ROWING_MACHINE,
      HealthWorkoutActivityType.SWIMMING,
      HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
      HealthWorkoutActivityType.SWIMMING_POOL,
      HealthWorkoutActivityType.HIKING,
      HealthWorkoutActivityType.DANCING,
      HealthWorkoutActivityType.CARDIO_DANCE,
      HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
      HealthWorkoutActivityType.MIXED_CARDIO,
      HealthWorkoutActivityType.CROSS_TRAINING,
      HealthWorkoutActivityType.JUMP_ROPE,
      HealthWorkoutActivityType.STAIR_CLIMBING,
      HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE,
      HealthWorkoutActivityType.STAIRS,
      HealthWorkoutActivityType.STEP_TRAINING,
      HealthWorkoutActivityType.YOGA,
      HealthWorkoutActivityType.PILATES,
      HealthWorkoutActivityType.OTHER, // 많은 앱이 OTHER로 기록
    };
    return aerobic.contains(type);
  }

  static String _mapAerobicToSurvey(int count) {
    if (count == 0) return '0';
    if (count <= 2) return '1-2';
    if (count <= 4) return '3-4';
    return '5+';
  }

  static String _mapResistanceToSurvey(int count) {
    if (count == 0) return '0';
    if (count == 1) return '1';
    if (count == 2) return '2';
    return '3+';
  }

  /// 오늘(1일)만 조회해 유산소·근력 30분+ 세션 횟수 반환. 생활습관 설문 계산 로직과 동일.
  static Future<TodayExerciseResult?> fetchTodaySessions() async {
    if (kIsWeb) return null;

    try {
      final health = Health();
      await health.configure();

      final allTypes = [..._workoutTypes, ..._activityTypes];
      final granted = await health.requestAuthorization(
        allTypes,
        permissions: List.filled(allTypes.length, HealthDataAccess.READ),
      );
      if (!granted) return null;

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);

      int aerobicMinutes = 0;
      int resistanceMinutes = 0;
      int aerobicSessions = 0;
      int resistanceSessions = 0;

      // 1) WORKOUT 세션
      final workoutPoints = await health.getHealthDataFromTypes(
        types: _workoutTypes,
        startTime: start,
        endTime: now,
      );
      for (final point in workoutPoints) {
        final value = point.value;
        if (value is! WorkoutHealthValue) continue;

        final durationMinutes = point.dateTo.difference(point.dateFrom).inMinutes;
        final effectiveMinutes = durationMinutes > 0 ? durationMinutes : 30;

        final type = value.workoutActivityType;
        if (_isResistanceType(type)) {
          resistanceMinutes += effectiveMinutes;
          if (durationMinutes <= 0) resistanceSessions += 1;
        } else if (_isAerobicType(type)) {
          aerobicMinutes += effectiveMinutes;
          if (durationMinutes <= 0) aerobicSessions += 1;
        } else {
          aerobicMinutes += effectiveMinutes;
          if (durationMinutes <= 0) aerobicSessions += 1;
        }
      }

      // 2) 걸음·거리·운동시간 (WORKOUT 없을 때)
      if (aerobicMinutes == 0) {
        final activityPoints = await health.getHealthDataFromTypes(
          types: _activityTypes,
          startTime: start,
          endTime: now,
        );
        int totalSteps = 0;
        double totalDistanceM = 0;
        int exerciseTimeMin = 0;

        for (final point in activityPoints) {
          final v = point.value;
          if (v is NumericHealthValue) {
            if (point.type == HealthDataType.STEPS) {
              totalSteps += v.numericValue.toInt();
            } else if (point.type == HealthDataType.DISTANCE_WALKING_RUNNING) {
              totalDistanceM += v.numericValue;
            } else if (point.type == HealthDataType.EXERCISE_TIME) {
              exerciseTimeMin += v.numericValue.toInt();
            }
          }
        }

        if (exerciseTimeMin > 0) {
          aerobicMinutes = exerciseTimeMin;
        } else {
          final stepsSessions = totalSteps ~/ 5000;
          final distanceSessions = (totalDistanceM / 2000).floor();
          final sessions = stepsSessions > distanceSessions ? stepsSessions : distanceSessions;
          aerobicMinutes = sessions * 30;
          if (aerobicMinutes == 0 && (totalSteps >= 2000 || totalDistanceM >= 800)) {
            aerobicMinutes = 30;
          }
        }
      }

      final aerobicCount = (aerobicMinutes ~/ 30).clamp(aerobicSessions, 100);
      final resistanceCount = (resistanceMinutes ~/ 30).clamp(resistanceSessions, 100);

      return TodayExerciseResult(
        aerobicSessions30min: aerobicCount,
        resistanceSessions30min: resistanceCount,
      );
    } catch (e) {
      debugPrint('[ExerciseAutoFillService] fetchTodaySessions Error: $e');
      return null;
    }
  }
}

class TodayExerciseResult {
  final int aerobicSessions30min;
  final int resistanceSessions30min;

  TodayExerciseResult({
    required this.aerobicSessions30min,
    required this.resistanceSessions30min,
  });
}

class ExerciseAutoFillResult {
  final String aerobicWeekly;
  final String resistanceWeekly;
  final int aerobicCount;
  final int resistanceCount;

  ExerciseAutoFillResult({
    required this.aerobicWeekly,
    required this.resistanceWeekly,
    required this.aerobicCount,
    required this.resistanceCount,
  });
}
