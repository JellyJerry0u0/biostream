import 'package:biostream/screens/result/result_screen_view_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResultScreenViewData', () {
    test('lifestyleData가 없으면 기본값을 사용한다', () {
      final viewData = ResultScreenViewData.fromLifestyleData(null);

      expect(viewData.currentAgeText, 'Now');
      expect(viewData.targetAgeText, '65');
      expect(viewData.managedSkinAge, isA<int>());
      expect(viewData.unmanagedSkinAge, isA<int>());
      expect(viewData.visualGap, isA<int>());
      expect(viewData.potentialPercentage, isA<double>());
      expect(viewData.collagenLabel, isNotEmpty);
      expect(viewData.uvLabel, isNotEmpty);
    });

    test('lifestyleData가 있으면 표시값을 계산한다', () {
      final lifestyleData = <String, dynamic>{
        'profile': {'age': '30 years'},
        'target_age': '40 years',
        'lifestyle': {
          'smoking': {'smoking_status': 'current'},
          'exercise': {
            'exercise_type': 'none',
            'daily_exercise_minutes': '10',
          },
          'sleep': {'average_sleep_hours': '5.5'},
          'uv': {'sunscreen_usage': 'none'},
          'drinking': {'drinking_frequency': 'daily'},
        },
      };

      final viewData = ResultScreenViewData.fromLifestyleData(lifestyleData);

      expect(viewData.currentAgeText, 'Now (30)');
      expect(viewData.targetAgeText, '70');
      expect(viewData.managedSkinAge, greaterThanOrEqualTo(30));
      expect(viewData.unmanagedSkinAge, greaterThanOrEqualTo(30));
      expect(viewData.visualGap, greaterThanOrEqualTo(0));
      expect(viewData.potentialPercentage, greaterThanOrEqualTo(0));
      expect(viewData.collagenColor, isA<Color>());
      expect(viewData.uvColor, isA<Color>());
    });
  });
}
