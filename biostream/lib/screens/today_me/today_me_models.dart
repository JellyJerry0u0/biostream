import 'package:flutter/material.dart';

/// 오늘의 나의 생활 편집 가능 항목
class TodayLifestyleItem {
  const TodayLifestyleItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.editable = true,
  });

  final String key;
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool editable;
}

/// 일별 생활 스냅샷 한 줄 (히스토리 API + 오늘 병합용)
class LifestyleHistoryDay {
  const LifestyleHistoryDay({
    required this.date,
    this.weightKg,
    this.heightCm,
    this.drinkingDaysPerWeek,
    this.smokingStatus,
    this.stressScore,
    this.sleepMinutes,
    this.sleepQualityScore,
    this.aerobicSessions30min,
    this.resistanceSessions30min,
    this.uvOutdoor10to16,
    this.sunscreenApplied,
  });

  final DateTime date;
  final double? weightKg;
  final double? heightCm;
  final String? drinkingDaysPerWeek;
  final String? smokingStatus;
  final double? stressScore;
  final int? sleepMinutes;
  final double? sleepQualityScore;
  final int? aerobicSessions30min;
  final int? resistanceSessions30min;
  final String? uvOutdoor10to16;
  final bool? sunscreenApplied;

  factory LifestyleHistoryDay.fromJson(Map<String, dynamic> j) {
    final dateStr = j['date']?.toString();
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    return LifestyleHistoryDay(
      date: date != null
          ? DateTime(date.year, date.month, date.day)
          : DateTime.now(),
      weightKg: (j['weightKg'] as num?)?.toDouble(),
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      drinkingDaysPerWeek: j['drinkingDaysPerWeek']?.toString(),
      smokingStatus: j['smokingStatus']?.toString(),
      stressScore: (j['stressScore'] as num?)?.toDouble(),
      sleepMinutes: (j['sleepMinutes'] as num?)?.toInt(),
      sleepQualityScore: (j['sleepQualityScore'] as num?)?.toDouble(),
      aerobicSessions30min: (j['aerobicSessions30min'] as num?)?.toInt(),
      resistanceSessions30min: (j['resistanceSessions30min'] as num?)?.toInt(),
      uvOutdoor10to16: j['uvOutdoor10to16']?.toString(),
      sunscreenApplied: j['sunscreenApplied'] is bool
          ? j['sunscreenApplied'] as bool
          : null,
    );
  }
}

class MetricItem {
  const MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool wide;
}
