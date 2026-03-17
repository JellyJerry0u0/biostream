import 'package:flutter/material.dart';

import '../../services/lifestyle_service.dart';
import 'today_me_models.dart';

class TodayMeMetricsLoadResult {
  const TodayMeMetricsLoadResult({
    this.metrics,
    this.notice,
  });

  final List<MetricItem>? metrics;
  final String? notice;
}

class TodayMeController {
  TodayMeController({required LifestyleService lifestyleService})
      : _lifestyleService = lifestyleService;

  final LifestyleService _lifestyleService;

  Future<TodayMeMetricsLoadResult> loadYesterdayMetrics() async {
    final profileBody = await _loadProfileBodyMetrics();
    final result = await _lifestyleService.getYesterdayHealthData();

    if (result['success'] != true) {
      final message = (result['message'] ?? '').toString();
      if (message.contains('어제 동기화된 건강 데이터가 없습니다')) {
        return const TodayMeMetricsLoadResult(
          notice: '어제 동기화 데이터가 없어 기본 표시값을 보여주고 있어요.',
        );
      }
      if (message.isNotEmpty) {
        return const TodayMeMetricsLoadResult(
          notice: '어제 건강 데이터를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
        );
      }
      return const TodayMeMetricsLoadResult();
    }

    final data = result['data'];
    if (data is! Map<String, dynamic>) {
      return const TodayMeMetricsLoadResult(
        notice: '어제 건강 데이터 형식을 확인할 수 없어요.',
      );
    }

    final distanceMeters = _toDouble(data['distanceMeters']);
    final exerciseMinutes = _toInt(data['exerciseMinutes']);
    final healthWeightKg = _toDouble(data['weightKg']);
    final healthHeightCm = _toDouble(data['heightCm']);
    final fallbackWeightKg = profileBody['weightKg'] ?? 0.0;
    final fallbackHeightCm = profileBody['heightCm'] ?? 0.0;
    final weightKg = healthWeightKg > 0 ? healthWeightKg : fallbackWeightKg;
    final heightCm = healthHeightCm > 0 ? healthHeightCm : fallbackHeightCm;
    final bodyFatPercentage = _toDouble(data['bodyFatPercentage']);
    final sleepMinutes = _toInt(data['sleepMinutes']);
    final nutritionCaloriesKcal = _toDouble(data['nutritionCaloriesKcal']);
    final oxygenSaturation = _toDouble(data['oxygenSaturation']);
    final bloodGlucoseMgDl = _toDouble(data['bloodGlucoseMgDl']);
    final vo2Max = _toDouble(data['vo2Max']);

    final notice = (healthWeightKg <= 0 && fallbackWeightKg > 0) ||
            (healthHeightCm <= 0 && fallbackHeightCm > 0)
        ? '체중/키는 회원가입 정보(프로필) 값을 표시하고 있어요.'
        : null;

    return TodayMeMetricsLoadResult(
      notice: notice,
      metrics: [
        MetricItem(
          icon: Icons.directions_walk,
          label: '거리',
          value: _fmtFixed(distanceMeters / 1000.0, 1),
          unit: 'km',
        ),
        MetricItem(
          icon: Icons.fitness_center,
          label: '운동',
          value: exerciseMinutes.toString(),
          unit: 'min',
        ),
        MetricItem(
          icon: Icons.monitor_weight,
          label: '체중',
          value: _fmtFixed(weightKg, 1),
          unit: 'kg',
        ),
        MetricItem(
          icon: Icons.height,
          label: '키',
          value: _fmtFixed(heightCm, 1),
          unit: 'cm',
        ),
        MetricItem(
          icon: Icons.opacity,
          label: '체지방',
          value: _fmtFixed(bodyFatPercentage, 1),
          unit: '%',
        ),
        MetricItem(
          icon: Icons.restaurant,
          label: '영양',
          value: _fmtFixed(nutritionCaloriesKcal, 0),
          unit: 'kcal',
        ),
        MetricItem(
          icon: Icons.air,
          label: '산소포화도',
          value: _fmtFixed(oxygenSaturation, 1),
          unit: '%',
        ),
        MetricItem(
          icon: Icons.bloodtype,
          label: '혈당',
          value: _fmtFixed(bloodGlucoseMgDl, 0),
          unit: 'mg/dL',
        ),
        MetricItem(
          icon: Icons.monitor_heart,
          label: '최대 산소 소비량 (VO2 Max)',
          value: _fmtFixed(vo2Max, 1),
          unit: 'ml/kg/min',
          wide: true,
        ),
        MetricItem(
          icon: Icons.bedtime,
          label: '수면',
          value: _fmtFixed(sleepMinutes / 60.0, 1),
          unit: 'hr',
        ),
      ],
    );
  }

  Future<Map<String, double>> _loadProfileBodyMetrics() async {
    final result = await _lifestyleService.getLifestyleData();
    if (result['success'] != true) {
      return {'weightKg': 0.0, 'heightCm': 0.0};
    }

    final data = result['data'];
    if (data is! Map<String, dynamic>) {
      return {'weightKg': 0.0, 'heightCm': 0.0};
    }

    final bodystate = data['bodystate'];
    if (bodystate is! Map<String, dynamic>) {
      return {'weightKg': 0.0, 'heightCm': 0.0};
    }

    return {
      'weightKg': _extractNumber(bodystate['weight_kg']),
      'heightCm': _extractNumber(bodystate['height_cm']),
    };
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _extractNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(value);
      if (match != null) {
        return double.tryParse(match.group(0) ?? '') ?? 0.0;
      }
    }
    return 0.0;
  }

  String _fmtFixed(double value, int fractionDigits) {
    return value.toStringAsFixed(fractionDigits);
  }
}
