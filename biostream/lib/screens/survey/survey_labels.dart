class SurveyLabels {
  static String mainGoalsSummary(List<String> outcomes) {
    if (outcomes.isEmpty) return '미입력';
    const labels = {
      'wrinkles': '주름',
      'elasticity': '탄력',
      'pigmentation': '색소침착',
      'hydration': '수분',
      'skin_barrier': '피부 장벽',
      'acne': '여드름',
      'redness': '홍조',
      'overall_aging': '전체 노화',
    };
    return outcomes.map((o) => labels[o] ?? o).join(', ');
  }

  static String uvExposureSummary({
    required String? uvExposure10to16,
    required String? sunscreenFrequency,
  }) {
    final parts = <String>[];
    if (uvExposure10to16 != null) {
      parts.add('야외노출: ${uvExposureLabel(uvExposure10to16)}');
    }
    if (sunscreenFrequency != null) {
      parts.add('선크림: ${sunscreenFrequencyLabel(sunscreenFrequency)}');
    }
    return parts.isEmpty ? '미입력' : parts.join(', ');
  }

  static String drinkingSmokingSummary({
    required String? drinkingDaysPerWeek,
    required String? smokingStatus,
    required String? smokingDaysPerWeek,
  }) {
    final parts = <String>[];
    if (drinkingDaysPerWeek != null) {
      parts.add('음주: ${drinkingDaysLabel(drinkingDaysPerWeek)}');
    }
    if (smokingStatus != null) {
      final smokingLabel = smokingStatus == 'never'
          ? '안함'
          : (smokingStatus == 'former' ? '과거 흡연' : '현재 흡연');
      parts.add('흡연: $smokingLabel');
      if (smokingStatus == 'current' && smokingDaysPerWeek != null) {
        parts.add('흡연일: ${drinkingDaysLabel(smokingDaysPerWeek)}');
      }
    }
    return parts.isEmpty ? '미입력' : parts.join(', ');
  }

  static String aerobicLabel(String? value) {
    const map = {'0': '0회', '1-2': '1-2회', '3-4': '3-4회', '5+': '5회 이상'};
    return map[value] ?? value ?? '미입력';
  }

  static String resistanceLabel(String? value) {
    const map = {'0': '0회', '1': '1회', '2': '2회', '3+': '3회 이상'};
    return map[value] ?? value ?? '미입력';
  }

  static String skinTypeLabel(String? value) {
    const map = {
      'dry': '건성',
      'oily': '지성',
      'combination': '복합성',
      'sensitive': '민감성',
    };
    return map[value] ?? value ?? '미입력';
  }

  static String uvExposureLabel(String? value) {
    const map = {
      '<30m': '30분 미만',
      '30~60': '30분~1시간',
      '1~2h': '1~2시간',
      '>2h': '2시간 이상',
    };
    return map[value] ?? value ?? '';
  }

  static String sunscreenFrequencyLabel(String? value) {
    const map = {
      'never': '안함',
      'sometimes': '가끔',
      'most_days': '대부분',
      'daily_with_reapply': '매일(재도포)',
      '0': '주 0회',
      '1': '주 1회',
      '2-3': '주 2~3회',
      '4-5': '주 4~5회',
      '6-7': '주 6~7회',
    };
    return map[value] ?? value ?? '';
  }

  static String drinkingDaysLabel(String? value) {
    const map = {
      '0': '0일',
      '1': '1일',
      '2-3': '2-3일',
      '4-5': '4-5일',
      '6-7': '6-7일',
    };
    return map[value] ?? value ?? '';
  }
}
