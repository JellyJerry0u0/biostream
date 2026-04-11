import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveyStressPage extends StatelessWidget {
  const SurveyStressPage({
    super.key,
    required this.isDark,
    required this.stressScore,
    required this.onStressScoreChanged,
    required this.sliderBuilder,
  });

  final bool isDark;
  final double stressScore;
  final ValueChanged<double> onStressScoreChanged;
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
                '스트레스',
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
            ],
          ),
        ),
      ),
    );
  }
}
