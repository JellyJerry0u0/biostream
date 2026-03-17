import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';

class SurveyTargetYearsPage extends StatelessWidget {
  const SurveyTargetYearsPage({
    super.key,
    required this.isDark,
    required this.targetYears,
    required this.onTargetYearsChanged,
  });

  final bool isDark;
  final double targetYears;
  final ValueChanged<double> onTargetYearsChanged;

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
                '목표 미래 나이',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 8)),
              Text(
                'AI 모델이 예측할 미래 시점을 선택하세요.',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Container(
                padding: EdgeInsets.all(Responsive.padding(context, 24)),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2C16) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '+${targetYears.toInt()}년 후',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 48),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF37EC13),
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 24)),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF37EC13),
                        inactiveTrackColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFD3E7CF),
                        thumbColor: const Color(0xFF37EC13),
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: Responsive.fontSize(context, 12),
                        ),
                      ),
                      child: Slider(
                        value: targetYears,
                        min: 10,
                        max: 50,
                        divisions: 4,
                        onChanged: onTargetYearsChanged,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _yearLabel(context, isDark, '+10년'),
                        _yearLabel(context, isDark, '+20년'),
                        Text(
                          '+30년',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 12),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF37EC13),
                          ),
                        ),
                        _yearLabel(context, isDark, '+40년'),
                        _yearLabel(context, isDark, '+50년'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _yearLabel(BuildContext context, bool isDark, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: Responsive.fontSize(context, 12),
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }
}
