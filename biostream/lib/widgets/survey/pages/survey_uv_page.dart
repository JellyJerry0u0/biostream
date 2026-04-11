import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveyUvPage extends StatelessWidget {
  const SurveyUvPage({
    super.key,
    required this.isDark,
    required this.uvExposure10to16,
    required this.sunscreenFrequency,
    required this.onUvExposureChanged,
    required this.onSunscreenFrequencyChanged,
    required this.choiceBuilder,
  });

  final bool isDark;
  final String? uvExposure10to16;
  final String? sunscreenFrequency;
  final ValueChanged<String?> onUvExposureChanged;
  final ValueChanged<String?> onSunscreenFrequencyChanged;
  final SurveyChoiceBuilder choiceBuilder;

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
                '자외선 및 광노화',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '10:00~16:00 야외 노출시간'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '<30m', 'label': '30분 미만'},
                  {'value': '30~60', 'label': '30분~1시간'},
                  {'value': '1~2h', 'label': '1~2시간'},
                  {'value': '>2h', 'label': '2시간 이상'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: uvExposure10to16 == option['value'],
                    onTap: () => onUvExposureChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '선크림 사용 빈도 (주 몇 회)'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0회'},
                  {'value': '1', 'label': '1회'},
                  {'value': '2-3', 'label': '2~3회'},
                  {'value': '4-5', 'label': '4~5회'},
                  {'value': '6-7', 'label': '6~7회'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: sunscreenFrequency == option['value'],
                    onTap: () => onSunscreenFrequencyChanged(option['value']),
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
