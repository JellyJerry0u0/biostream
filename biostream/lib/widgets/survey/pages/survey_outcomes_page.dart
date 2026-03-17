import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveyOutcomesPage extends StatelessWidget {
  const SurveyOutcomesPage({
    super.key,
    required this.isDark,
    required this.outcomes,
    required this.onToggleOutcome,
    required this.chipBuilder,
  });

  final bool isDark;
  final List<String> outcomes;
  final ValueChanged<String> onToggleOutcome;
  final SurveyChipBuilder chipBuilder;

  @override
  Widget build(BuildContext context) {
    const options = [
      {'value': 'wrinkle', 'label': '주름'},
      {'value': 'elasticity', 'label': '탄력'},
      {'value': 'pigmentation', 'label': '색소'},
      {'value': 'hydration', 'label': '수분'},
      {'value': 'hydration_barrier', 'label': '장벽'},
      {'value': 'acne', 'label': '여드름'},
      {'value': 'redness', 'label': '홍조'},
      {'value': 'general_aging', 'label': '전체 노화'},
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
                '주요 목표',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 8)),
              Text(
                '관심 있는 피부 고민을 선택해주세요 (복수 선택 가능)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: options.map((option) {
                  final value = option['value']!;
                  return chipBuilder(
                    label: option['label']!,
                    isSelected: outcomes.contains(value),
                    onTap: () => onToggleOutcome(value),
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
}
