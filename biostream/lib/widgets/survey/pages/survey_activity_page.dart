import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveyActivityPage extends StatelessWidget {
  const SurveyActivityPage({
    super.key,
    required this.isDark,
    required this.aerobicWeekly,
    required this.resistanceWeekly,
    required this.height,
    required this.weight,
    required this.onAerobicWeeklyChanged,
    required this.onResistanceWeeklyChanged,
    required this.onHeightChanged,
    required this.onWeightChanged,
    required this.choiceBuilder,
    required this.integerFieldBuilder,
    this.prefillHint,
  });

  final bool isDark;
  final String? aerobicWeekly;
  final String? resistanceWeekly;
  final double? height;
  final double? weight;
  final ValueChanged<String?> onAerobicWeeklyChanged;
  final ValueChanged<String?> onResistanceWeeklyChanged;
  final ValueChanged<int?> onHeightChanged;
  final ValueChanged<int?> onWeightChanged;
  final SurveyChoiceBuilder choiceBuilder;
  final SurveyIntegerFieldBuilder integerFieldBuilder;
  final String? prefillHint;

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
                '활동 및 대사',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if ((prefillHint ?? '').isNotEmpty) ...[
                SizedBox(height: Responsive.padding(context, 12)),
                Text(
                  prefillHint ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '유산소 (주당)'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0회'},
                  {'value': '1-2', 'label': '1-2회'},
                  {'value': '3-4', 'label': '3-4회'},
                  {'value': '5+', 'label': '5회 이상'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: aerobicWeekly == option['value'],
                    onTap: () => onAerobicWeeklyChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '근력 (주당)'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0회'},
                  {'value': '1', 'label': '1회'},
                  {'value': '2', 'label': '2회'},
                  {'value': '3+', 'label': '3회 이상'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: resistanceWeekly == option['value'],
                    onTap: () => onResistanceWeeklyChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Row(
                children: [
                  Expanded(
                    child: integerFieldBuilder(
                      label: '키 (cm)',
                      value: height?.toInt(),
                      placeholder: '170',
                      onChanged: onHeightChanged,
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(width: Responsive.padding(context, 16)),
                  Expanded(
                    child: integerFieldBuilder(
                      label: '몸무게 (kg)',
                      value: weight?.toInt(),
                      placeholder: '60',
                      onChanged: onWeightChanged,
                      isDark: isDark,
                    ),
                  ),
                ],
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
