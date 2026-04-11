import 'package:flutter/material.dart';

import '../common/face_comparison_slider.dart';

/// 미래 얼굴 비교 화면용 — [FaceComparisonSlider] 래퍼
class FutureFaceComparisonSlider extends StatelessWidget {
  const FutureFaceComparisonSlider({
    super.key,
    required this.isDark,
    required this.isLoading,
    required this.leftImageUrl,
    required this.futureImageUrl,
    required this.imageError,
    required this.sliderRatio,
    required this.primaryColor,
    required this.onSliderRatioChanged,
    this.showEdgeLabels = false,
  });

  final bool isDark;
  final bool isLoading;
  final String? leftImageUrl;
  final String? futureImageUrl;
  final String? imageError;
  final double sliderRatio;
  final Color primaryColor;
  final ValueChanged<double> onSliderRatioChanged;
  final bool showEdgeLabels;

  @override
  Widget build(BuildContext context) {
    return FaceComparisonSlider(
      isDark: isDark,
      isLoading: isLoading,
      leftImageUrl: leftImageUrl,
      rightImageUrl: futureImageUrl,
      imageError: imageError,
      sliderRatio: sliderRatio,
      primaryColor: primaryColor,
      onSliderRatioChanged: onSliderRatioChanged,
      leftLabel: '습관 만점',
      rightLabel: '생활습관 반영',
      showEdgeLabels: showEdgeLabels,
      borderRadius: 18,
    );
  }
}
