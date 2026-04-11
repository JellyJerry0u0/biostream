import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../common/face_comparison_slider.dart';

class ResultAgingSimulationSection extends StatefulWidget {
  final bool isDark;
  /// 프로필 실제 나이(만 나이 등 서버에서 오는 값)
  final int chronologicalAge;
  /// 시뮬레이션 시간 범위(년). 보통 30.
  final int agingHorizonYears;
  final String? originalImageUrl;
  final String? generatedImageUrl;

  const ResultAgingSimulationSection({
    super.key,
    required this.isDark,
    required this.chronologicalAge,
    required this.agingHorizonYears,
    required this.originalImageUrl,
    required this.generatedImageUrl,
  });

  @override
  State<ResultAgingSimulationSection> createState() =>
      _ResultAgingSimulationSectionState();
}

class _ResultAgingSimulationSectionState
    extends State<ResultAgingSimulationSection> {
  static const Color _primary = Color(0xFF37EC13);
  double _sliderRatio = 0.5;

  @override
  Widget build(BuildContext context) {
    final hasBoth = widget.originalImageUrl != null &&
        widget.originalImageUrl!.isNotEmpty &&
        widget.generatedImageUrl != null &&
        widget.generatedImageUrl!.isNotEmpty;

    return Column(
      children: [
        Text(
          'Aging Scenario',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 24),
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white : const Color(0xFF101B0D),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _primary.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.12),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: FaceComparisonSlider(
            isDark: widget.isDark,
            isLoading: false,
            leftImageUrl: hasBoth ? widget.originalImageUrl : null,
            rightImageUrl: hasBoth ? widget.generatedImageUrl : null,
            imageError: '리포트 이미지를 불러올 수 없습니다.',
            sliderRatio: _sliderRatio,
            primaryColor: _primary,
            onSliderRatioChanged: (v) => setState(() => _sliderRatio = v),
            borderRadius: 20,
            leftLabel: '원본',
            rightLabel: '생활습관 반영',
            aspectRatio: 3 / 4,
          ),
        ),
        SizedBox(height: Responsive.padding(context, 14)),
        _chronologicalAgeCaption(context),
        SizedBox(height: Responsive.padding(context, 10)),
        _scenarioDisclaimer(context),
        SizedBox(height: Responsive.padding(context, 16)),
      ],
    );
  }

  Widget _chronologicalAgeCaption(BuildContext context) {
    final years = widget.agingHorizonYears;
    final targetAge = widget.chronologicalAge + years;
    final bodyColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.grey[700]!;
    final emphasisColor =
        widget.isDark ? Colors.white : const Color(0xFF101B0D);
    final hintColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.grey[600]!;
    final body = TextStyle(
      fontSize: Responsive.fontSize(context, 15),
      fontWeight: FontWeight.w500,
      height: 1.35,
      color: bodyColor,
    );
    final emphasis = TextStyle(
      fontSize: Responsive.fontSize(context, 22),
      fontWeight: FontWeight.bold,
      height: 1.25,
      color: emphasisColor,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: body,
            children: [
              const TextSpan(text: '현재 '),
              TextSpan(text: '${widget.chronologicalAge}세', style: emphasis),
              TextSpan(text: '  ·  +$years년 뒤 '),
              TextSpan(text: '$targetAge' '세', style: emphasis),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: Responsive.padding(context, 6)),
        Text(
          '지금 나이에서 $years년이 지난 모습을 비교합니다.',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 12),
            height: 1.35,
            color: hintColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 의학·법적 면책에 가까운 안내 (시뮬레이션임을 분명히 함)
  Widget _scenarioDisclaimer(BuildContext context) {
    final border = widget.isDark
        ? Colors.amber.shade700.withValues(alpha: 0.55)
        : Colors.amber.shade800.withValues(alpha: 0.35);
    final fill = widget.isDark
        ? Colors.amber.shade900.withValues(alpha: 0.12)
        : Colors.amber.shade50.withValues(alpha: 0.85);
    final iconColor =
        widget.isDark ? Colors.amber.shade400 : Colors.amber.shade900;
    final textColor = widget.isDark
        ? Colors.amber.shade100.withValues(alpha: 0.88)
        : Colors.brown.shade800.withValues(alpha: 0.9);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 12),
        vertical: Responsive.padding(context, 10),
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: Responsive.iconSize(context, 20),
            color: iconColor,
          ),
          SizedBox(width: Responsive.padding(context, 10)),
          Expanded(
            child: Text(
              '의학적 진단·예측이 아닙니다. 참고용 노화 시나리오 시뮬레이션이며, '
              '실제 노화나 건강 상태와 다를 수 있습니다.',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 10.5),
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
