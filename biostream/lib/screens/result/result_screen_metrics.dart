import 'package:flutter/material.dart';

class ResultScreenMetrics {
  static String getTargetAge(Map<String, dynamic>? lifestyleData) {
    if (lifestyleData?['target_age'] != null) {
      final targetAgeStr = lifestyleData!['target_age'].toString();
      final match = RegExp(r'(\d+)').firstMatch(targetAgeStr);
      if (match != null) {
        final years = int.tryParse(match.group(1) ?? '');
        if (years != null && lifestyleData['profile']?['age'] != null) {
          final currentAgeStr =
              lifestyleData['profile']['age'].toString().split(' ')[0];
          final currentAge = int.tryParse(currentAgeStr) ?? 0;
          return '${currentAge + years}';
        }
      }
    }
    return '65';
  }

  static int getCurrentAge(Map<String, dynamic>? lifestyleData) {
    if (lifestyleData?['profile']?['age'] != null) {
      final ageStr = lifestyleData!['profile']['age'].toString().split(' ')[0];
      return int.tryParse(ageStr) ?? 29;
    }
    return 29;
  }

  static int getTargetYears(Map<String, dynamic>? lifestyleData) {
    if (lifestyleData?['target_age'] != null) {
      final targetAgeStr = lifestyleData!['target_age'].toString();
      final match = RegExp(r'(\d+)').firstMatch(targetAgeStr);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '') ?? 36;
      }
    }
    return 36;
  }

  static int calculateManagedSkinAge(
    Map<String, dynamic>? lifestyleData, {
    required int currentAge,
    required int targetYears,
  }) {
    final lifestyle = lifestyleData?['lifestyle'];
    if (lifestyle == null) return currentAge + (targetYears ~/ 2);

    int agingFactor = 0;

    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        agingFactor += targetYears ~/ 3;
      } else if (status.contains('과거') || status.contains('past')) {
        agingFactor += targetYears ~/ 5;
      }
    }

    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType =
          exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        agingFactor += targetYears ~/ 4;
      }

      final dailyMins = exercise['daily_exercise_minutes'];
      if (dailyMins != null) {
        final minsStr = dailyMins.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final mins = int.tryParse(minsStr) ?? 0;
        if (mins < 30) {
          agingFactor += targetYears ~/ 6;
        }
      }
    }

    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr =
            sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          agingFactor += targetYears ~/ 6;
        }
      }
    }

    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') ||
          sunscreen.contains('none') ||
          sunscreen.contains('가끔')) {
        agingFactor += targetYears ~/ 2;
      }
    }

    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency =
          drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        agingFactor += targetYears ~/ 4;
      } else if (frequency.contains('주3') || frequency.contains('주4')) {
        agingFactor += targetYears ~/ 5;
      }
    }

    return currentAge + (agingFactor ~/ 3) + (targetYears ~/ 2);
  }

  static int calculateUnmanagedSkinAge(
    Map<String, dynamic>? lifestyleData, {
    required int currentAge,
    required int targetYears,
  }) {
    final lifestyle = lifestyleData?['lifestyle'];
    if (lifestyle == null) return currentAge + targetYears;

    int agingFactor = 0;

    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        agingFactor += targetYears ~/ 2;
      } else if (status.contains('과거') || status.contains('past')) {
        agingFactor += targetYears ~/ 3;
      }
    }

    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType =
          exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        agingFactor += targetYears ~/ 2;
      }

      final dailyMins = exercise['daily_exercise_minutes'];
      if (dailyMins != null) {
        final minsStr = dailyMins.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final mins = int.tryParse(minsStr) ?? 0;
        if (mins < 30) {
          agingFactor += targetYears ~/ 3;
        }
      }
    }

    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr =
            sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          agingFactor += targetYears ~/ 3;
        }
      }
    }

    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') || sunscreen.contains('none')) {
        agingFactor += targetYears;
      } else if (sunscreen.contains('가끔')) {
        agingFactor += targetYears ~/ 2;
      }
    }

    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency =
          drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        agingFactor += targetYears ~/ 2;
      } else if (frequency.contains('주3') || frequency.contains('주4')) {
        agingFactor += targetYears ~/ 3;
      }
    }

    return currentAge + agingFactor + targetYears;
  }

  static int getVisualGap(Map<String, dynamic>? lifestyleData) {
    final currentAge = getCurrentAge(lifestyleData);
    final targetYears = getTargetYears(lifestyleData);
    final managedAge = calculateManagedSkinAge(
      lifestyleData,
      currentAge: currentAge,
      targetYears: targetYears,
    );
    final unmanagedAge = calculateUnmanagedSkinAge(
      lifestyleData,
      currentAge: currentAge,
      targetYears: targetYears,
    );
    return (unmanagedAge - managedAge).abs();
  }

  static double getPotentialPercentage(Map<String, dynamic>? lifestyleData) {
    final currentAge = getCurrentAge(lifestyleData);
    final targetYears = getTargetYears(lifestyleData);
    final managedAge = calculateManagedSkinAge(
      lifestyleData,
      currentAge: currentAge,
      targetYears: targetYears,
    );
    final unmanagedAge = calculateUnmanagedSkinAge(
      lifestyleData,
      currentAge: currentAge,
      targetYears: targetYears,
    );

    if (unmanagedAge == 0) return 0.0;
    final difference = unmanagedAge - managedAge;
    final percentage = (difference / unmanagedAge) * 100;
    return percentage.abs();
  }

  static Map<String, dynamic> getCollagenPreservationImpact(
    Map<String, dynamic>? lifestyleData,
  ) {
    final lifestyle = lifestyleData?['lifestyle'];
    if (lifestyle == null) {
      return {'level': 'medium', 'score': 0.5, 'label': 'Medium Impact'};
    }

    double impactScore = 0.0;
    int factorCount = 0;

    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        impactScore += 0.9;
        factorCount++;
      } else if (status.contains('과거') || status.contains('past')) {
        impactScore += 0.5;
        factorCount++;
      }
    }

    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType =
          exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        impactScore += 0.7;
        factorCount++;
      }
    }

    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr =
            sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          impactScore += 0.6;
          factorCount++;
        }
      }
    }

    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency =
          drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        impactScore += 0.8;
        factorCount++;
      }
    }

    final normalizedScore = factorCount > 0 ? impactScore / factorCount : 0.0;
    if (normalizedScore >= 0.7) {
      return {
        'level': 'high',
        'score': normalizedScore,
        'label': 'High Impact'
      };
    } else if (normalizedScore >= 0.4) {
      return {
        'level': 'medium',
        'score': normalizedScore,
        'label': 'Medium Impact'
      };
    }
    return {'level': 'low', 'score': normalizedScore, 'label': 'Low Impact'};
  }

  static Map<String, dynamic> getUvDamageControlImpact(
    Map<String, dynamic>? lifestyleData,
  ) {
    final lifestyle = lifestyleData?['lifestyle'];
    if (lifestyle == null) {
      return {'level': 'medium', 'score': 0.5, 'label': 'Medium Impact'};
    }

    double impactScore = 0.0;
    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') || sunscreen.contains('none')) {
        impactScore = 0.9;
      } else if (sunscreen.contains('가끔')) {
        impactScore = 0.6;
      } else if (sunscreen.contains('매일') || sunscreen.contains('daily')) {
        impactScore = 0.2;
      }
    }

    if (impactScore >= 0.7) {
      return {'level': 'high', 'score': impactScore, 'label': 'High Impact'};
    } else if (impactScore >= 0.4) {
      return {
        'level': 'medium',
        'score': impactScore,
        'label': 'Medium Impact'
      };
    }
    return {'level': 'low', 'score': impactScore, 'label': 'Low Impact'};
  }

  static Color getImpactColor(String level) {
    switch (level) {
      case 'high':
        return Colors.red[500]!;
      case 'medium':
        return Colors.yellow[500]!;
      case 'low':
        return Colors.green[500]!;
      default:
        return Colors.grey[500]!;
    }
  }
}
