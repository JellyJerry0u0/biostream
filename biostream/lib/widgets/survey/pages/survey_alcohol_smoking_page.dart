import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';
import '../common/survey_types.dart';

class SurveyAlcoholSmokingPage extends StatelessWidget {
  const SurveyAlcoholSmokingPage({
    super.key,
    required this.isDark,
    required this.drinkingDaysPerWeek,
    required this.drinkingAmountPerSession,
    required this.smokingStatus,
    required this.smokingAmountUnit,
    required this.smokingAmountController,
    required this.onDrinkingDaysChanged,
    required this.onDrinkingAmountChanged,
    required this.onSmokingStatusChanged,
    required this.onSmokingAmountUnitChanged,
    required this.choiceBuilder,
    required this.textFieldBuilder,
    required this.numberFieldBuilder,
  });

  final bool isDark;
  final String? drinkingDaysPerWeek;
  final String? drinkingAmountPerSession;
  final String? smokingStatus;
  final String? smokingAmountUnit;
  final TextEditingController smokingAmountController;
  final ValueChanged<String?> onDrinkingDaysChanged;
  final ValueChanged<String?> onDrinkingAmountChanged;
  final ValueChanged<String?> onSmokingStatusChanged;
  final ValueChanged<String?> onSmokingAmountUnitChanged;
  final SurveyChoiceBuilder choiceBuilder;
  final SurveyTextFieldBuilder textFieldBuilder;
  final SurveyNumberFieldBuilder numberFieldBuilder;

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
                '음주 및 흡연',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '주당 음주일수'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0일'},
                  {'value': '1', 'label': '1일'},
                  {'value': '2-3', 'label': '2-3일'},
                  {'value': '4-5', 'label': '4-5일'},
                  {'value': '6-7', 'label': '6-7일'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: drinkingDaysPerWeek == option['value'],
                    onTap: () => onDrinkingDaysChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '1회 음주량'),
              SizedBox(height: Responsive.padding(context, 16)),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 40)),
                child: textFieldBuilder(
                  label: '',
                  value: drinkingAmountPerSession,
                  placeholder: '예: 소주 5잔, 맥주 2병',
                  onChanged: onDrinkingAmountChanged,
                  isDark: isDark,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _title(context, '흡연/니코틴'),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'never', 'label': '안함'},
                  {'value': 'former', 'label': '과거 흡연'},
                  {'value': 'current', 'label': '현재 흡연'},
                ].map((option) {
                  return choiceBuilder(
                    label: option['label']!,
                    isSelected: smokingStatus == option['value'],
                    onTap: () => onSmokingStatusChanged(option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              if (smokingStatus == 'current') ...[
                SizedBox(height: Responsive.padding(context, 32)),
                _title(context, '흡연량 단위'),
                SizedBox(height: Responsive.padding(context, 16)),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Responsive.padding(context, 12),
                  runSpacing: Responsive.padding(context, 12),
                  children: [
                    {'value': '갑', 'label': '갑'},
                    {'value': '개비', 'label': '개비'},
                  ].map((option) {
                    return choiceBuilder(
                      label: option['label']!,
                      isSelected: smokingAmountUnit == option['value'],
                      onTap: () => onSmokingAmountUnitChanged(option['value']),
                      isDark: isDark,
                    );
                  }).toList(),
                ),
                if (smokingAmountUnit != null) ...[
                  SizedBox(height: Responsive.padding(context, 32)),
                  _title(context, '하루 흡연량'),
                  SizedBox(height: Responsive.padding(context, 16)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(context, 40)),
                    child: numberFieldBuilder(
                      label: '',
                      controller: smokingAmountController,
                      placeholder: '0',
                      suffix: smokingAmountUnit!,
                      isDark: isDark,
                    ),
                  ),
                ],
              ],
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
