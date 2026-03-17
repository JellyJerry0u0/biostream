import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveyStressPage extends StatelessWidget {
  const SurveyStressPage({
    super.key,
    required this.isDark,
    required this.stressScore,
    required this.caffeineIntake,
    required this.caffeineTiming,
    required this.onStressScoreChanged,
    required this.onCaffeineIntakeChanged,
    required this.onCaffeineTimingChanged,
    required this.choiceBuilder,
    required this.sliderBuilder,
  });

  final bool isDark;
  final double stressScore;
  final String? caffeineIntake;
  final String? caffeineTiming;
  final ValueChanged<double> onStressScoreChanged;
  final ValueChanged<String?> onCaffeineIntakeChanged;
  final ValueChanged<String?> onCaffeineTimingChanged;
  final SurveyChoiceBuilder choiceBuilder;
  final SurveySliderBuilder sliderBuilder;

  @override
  Widget build(BuildContext context) {
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
                '스트레스 및 회복',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              sliderBuilder(
                label: '스트레스 (지난 2주)',
                value: stressScore,
                min: 0.0,
                max: 10.0,
                divisions: 10,
                suffix: '점',
                isInteger: true,
                onChanged: onStressScoreChanged,
                isDark: isDark,
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '카페인 섭취량'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0잔'},
                  {'value': '1', 'label': '1잔'},
                  {'value': '2', 'label': '2잔'},
                  {'value': '3+', 'label': '3잔 이상'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: caffeineIntake == option['value'],
                    onTap: () => onCaffeineIntakeChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '카페인 섭취 시간대'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'before_noon', 'label': '오전'},
                  {'value': 'afternoon', 'label': '오후'},
                  {'value': 'evening', 'label': '저녁'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: caffeineTiming == option['value'],
                    onTap: () => onCaffeineTimingChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
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
