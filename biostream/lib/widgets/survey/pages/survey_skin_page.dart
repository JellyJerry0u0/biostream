import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveySkinPage extends StatelessWidget {
  const SurveySkinPage({
    super.key,
    required this.isDark,
    required this.skinType,
    required this.skinConcerns,
    required this.skinSatisfaction,
    required this.onSkinTypeChanged,
    required this.onSkinConcernToggled,
    required this.onSkinSatisfactionChanged,
    required this.choiceBuilder,
    required this.chipBuilder,
    required this.sliderBuilder,
  });

  final bool isDark;
  final String? skinType;
  final List<String> skinConcerns;
  final double skinSatisfaction;
  final ValueChanged<String?> onSkinTypeChanged;
  final ValueChanged<String> onSkinConcernToggled;
  final ValueChanged<double> onSkinSatisfactionChanged;
  final SurveyChoiceBuilder choiceBuilder;
  final SurveyChipBuilder chipBuilder;
  final SurveySliderBuilder sliderBuilder;

  @override
  Widget build(BuildContext context) {
    const skinTypes = [
      {'value': 'dry', 'label': '건성'},
      {'value': 'oily', 'label': '지성'},
      {'value': 'combination', 'label': '복합성'},
      {'value': 'sensitive', 'label': '민감성'},
    ];

    const skinConcernOptions = [
      {'value': 'wrinkle', 'label': '주름'},
      {'value': 'pigmentation', 'label': '색소'},
      {'value': 'elasticity', 'label': '탄력'},
      {'value': 'dryness', 'label': '건조'},
      {'value': 'redness', 'label': '홍조'},
      {'value': 'acne', 'label': '트러블'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '피부 상태',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '피부 타입'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: skinTypes.map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: skinType == option['value'],
                    onTap: () => onSkinTypeChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 24)),
              Text(
                '주요 피부 고민 (복수 선택 가능)',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: skinConcernOptions.map((option) {
                  final value = option['value']!;
                  return chipBuilder(
                    label: option['label']!,
                    isSelected: skinConcerns.contains(value),
                    onTap: () => onSkinConcernToggled(value),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              sliderBuilder(
                label: '현재 피부상태 만족도',
                value: skinSatisfaction,
                min: 0.0,
                max: 10.0,
                divisions: 10,
                suffix: '점',
                isInteger: true,
                onChanged: onSkinSatisfactionChanged,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: Responsive.fontSize(context, 16),
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.grey[300] : Colors.grey[700],
      ),
    );
  }
}
