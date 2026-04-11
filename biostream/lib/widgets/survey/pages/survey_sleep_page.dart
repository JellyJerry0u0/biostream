import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveySleepPage extends StatelessWidget {
  const SurveySleepPage({
    super.key,
    required this.isDark,
    required this.sleepHoursWeekday,
    required this.sleepHoursWeekend,
    required this.sleepQualityScore,
    required this.onSleepHoursWeekdayChanged,
    required this.onSleepHoursWeekendChanged,
    required this.onSleepQualityScoreChanged,
    required this.sliderBuilder,
    this.prefillHint,
  });

  final bool isDark;
  final double sleepHoursWeekday;
  final double sleepHoursWeekend;
  final double sleepQualityScore;
  final ValueChanged<double> onSleepHoursWeekdayChanged;
  final ValueChanged<double> onSleepHoursWeekendChanged;
  final ValueChanged<double> onSleepQualityScoreChanged;
  final SurveySliderBuilder sliderBuilder;
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
                '수면 패턴',
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
              sliderBuilder(
                label: '평균 수면시간 (평일)',
                value: sleepHoursWeekday,
                min: 3.0,
                max: 10.0,
                divisions: 7,
                suffix: '시간',
                isInteger: true,
                onChanged: onSleepHoursWeekdayChanged,
                isDark: isDark,
              ),
              SizedBox(height: Responsive.padding(context, 24)),
              sliderBuilder(
                label: '평균 수면시간 (주말)',
                value: sleepHoursWeekend,
                min: 3.0,
                max: 10.0,
                divisions: 7,
                suffix: '시간',
                isInteger: true,
                onChanged: onSleepHoursWeekendChanged,
                isDark: isDark,
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              sliderBuilder(
                label: '수면의 질 (주관)',
                value: sleepQualityScore,
                min: 0.0,
                max: 10.0,
                divisions: 10,
                suffix: '점',
                isInteger: true,
                onChanged: onSleepQualityScoreChanged,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
