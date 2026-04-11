import 'package:biostream/screens/survey/survey_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SurveyLabels', () {
    test('mainGoalsSummary returns mapped labels', () {
      final summary = SurveyLabels.mainGoalsSummary([
        'elasticity',
        'acne',
      ]);

      expect(summary, '탄력, 여드름');
    });

    test('uvExposureSummary composes all selected parts', () {
      final summary = SurveyLabels.uvExposureSummary(
        uvExposure10to16: '1~2h',
        sunscreenFrequency: '6-7',
      );

      expect(summary, '야외노출: 1~2시간, 선크림: 주 6~7회');
    });

    test('drinkingSmokingSummary includes smoking days when current', () {
      final summary = SurveyLabels.drinkingSmokingSummary(
        drinkingDaysPerWeek: '2-3',
        smokingStatus: 'current',
        smokingDaysPerWeek: '4-5',
      );

      expect(summary, '음주: 2-3일, 흡연: 현재 흡연, 흡연일: 4-5일');
    });

    test('skin type label maps known values', () {
      expect(SurveyLabels.skinTypeLabel('sensitive'), '민감성');
    });
  });
}
