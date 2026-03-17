import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveyUvPage extends StatelessWidget {
  const SurveyUvPage({
    super.key,
    required this.isDark,
    required this.uvExposure10to16,
    required this.sunscreenFrequency,
    required this.sunscreenReapply,
    required this.outdoorSportsUv,
    required this.onUvExposureChanged,
    required this.onSunscreenFrequencyChanged,
    required this.onSunscreenReapplyChanged,
    required this.onOutdoorSportsUvChanged,
    required this.choiceBuilder,
  });

  final bool isDark;
  final String? uvExposure10to16;
  final String? sunscreenFrequency;
  final String? sunscreenReapply;
  final String? outdoorSportsUv;
  final ValueChanged<String?> onUvExposureChanged;
  final ValueChanged<String?> onSunscreenFrequencyChanged;
  final ValueChanged<String?> onSunscreenReapplyChanged;
  final ValueChanged<String?> onOutdoorSportsUvChanged;
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
              _title(context, '선크림 사용 빈도'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'never', 'label': '안함'},
                  {'value': 'sometimes', 'label': '가끔'},
                  {'value': 'most_days', 'label': '대부분'},
                  {'value': 'daily_with_reapply', 'label': '매일 (재도포 포함)'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: sunscreenFrequency == option['value'],
                    onTap: () => onSunscreenFrequencyChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '재도포 (2~3시간 간격)'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'never', 'label': '안함'},
                  {'value': 'rarely', 'label': '드물게'},
                  {'value': 'sometimes', 'label': '가끔'},
                  {'value': 'often', 'label': '자주'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: sunscreenReapply == option['value'],
                    onTap: () => onSunscreenReapplyChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '야외스포츠 (강한 UV)'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'none', 'label': '안함'},
                  {'value': 'monthly', 'label': '월 1회'},
                  {'value': 'weekly', 'label': '주 1회 이상'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: outdoorSportsUv == option['value'],
                    onTap: () => onOutdoorSportsUvChanged(option['value']),
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
