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
        sunscreenFrequency: 'most_days',
        sunscreenReapply: 'often',
        outdoorSportsUv: 'weekly',
      );

      expect(
        summary,
        '야외노출: 1~2시간, 선크림: 대부분, 재도포: 자주, 야외스포츠: 주 1회 이상',
      );
    });

    test('drinkingSmokingSummary includes smoking amount only when current',
        () {
      final summary = SurveyLabels.drinkingSmokingSummary(
        drinkingDaysPerWeek: '2-3',
        drinkingAmountPerSession: '맥주 2병',
        smokingStatus: 'current',
        smokingAmountUnit: '개비',
        smokingAmountText: '5',
      );

      expect(summary, '음주: 2-3일, 1회량: 맥주 2병, 흡연: 현재 흡연, 5개비');
    });

    test('skin labels map known values and keep fallback', () {
      expect(SurveyLabels.skinTypeLabel('sensitive'), '민감성');
      expect(SurveyLabels.skinConcernLabel('unknown_issue'), 'unknown_issue');
    });
  });
}
