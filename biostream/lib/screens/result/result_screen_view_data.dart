import 'package:flutter/material.dart';

import 'result_screen_metrics.dart';

class ResultScreenViewData {
  const ResultScreenViewData({
    required this.currentAgeText,
    required this.targetAgeText,
    required this.managedSkinAge,
    required this.unmanagedSkinAge,
    required this.visualGap,
    required this.potentialPercentage,
    required this.collagenLabel,
    required this.collagenScore,
    required this.collagenColor,
    required this.uvLabel,
    required this.uvScore,
    required this.uvColor,
  });

  final String currentAgeText;
  final String targetAgeText;
  final int managedSkinAge;
  final int unmanagedSkinAge;
  final int visualGap;
  final double potentialPercentage;
  final String collagenLabel;
  final double collagenScore;
  final Color collagenColor;
  final String uvLabel;
  final double uvScore;
  final Color uvColor;

  factory ResultScreenViewData.fromLifestyleData(
    Map<String, dynamic>? lifestyleData,
  ) {
    final currentAgeText = lifestyleData?['profile']?['age'] != null
        ? 'Now (${lifestyleData!['profile']['age'].toString().split(' ')[0]})'
        : 'Now';

    final currentAge = ResultScreenMetrics.getCurrentAge(lifestyleData);
    final targetYears = ResultScreenMetrics.getTargetYears(lifestyleData);

    final managedSkinAge = ResultScreenMetrics.calculateManagedSkinAge(
      lifestyleData,
      currentAge: currentAge,
      targetYears: targetYears,
    );
    final unmanagedSkinAge = ResultScreenMetrics.calculateUnmanagedSkinAge(
      lifestyleData,
      currentAge: currentAge,
      targetYears: targetYears,
    );

    final collagenImpact =
        ResultScreenMetrics.getCollagenPreservationImpact(lifestyleData);
    final uvImpact =
        ResultScreenMetrics.getUvDamageControlImpact(lifestyleData);

    return ResultScreenViewData(
      currentAgeText: currentAgeText,
      targetAgeText: ResultScreenMetrics.getTargetAge(lifestyleData),
      managedSkinAge: managedSkinAge,
      unmanagedSkinAge: unmanagedSkinAge,
      visualGap: ResultScreenMetrics.getVisualGap(lifestyleData),
      potentialPercentage: ResultScreenMetrics.getPotentialPercentage(
        lifestyleData,
      ),
      collagenLabel: collagenImpact['label']?.toString() ?? '-',
      collagenScore: (collagenImpact['score'] as num?)?.toDouble() ?? 0.0,
      collagenColor:
          ResultScreenMetrics.getImpactColor(collagenImpact['level']),
      uvLabel: uvImpact['label']?.toString() ?? '-',
      uvScore: (uvImpact['score'] as num?)?.toDouble() ?? 0.0,
      uvColor: ResultScreenMetrics.getImpactColor(uvImpact['level']),
    );
  }
}
