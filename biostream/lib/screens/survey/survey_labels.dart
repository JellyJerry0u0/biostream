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
    required String? sunscreenReapply,
    required String? outdoorSportsUv,
  }) {
    final parts = <String>[];
    if (uvExposure10to16 != null) {
      parts.add('야외노출: ${uvExposureLabel(uvExposure10to16)}');
    }
    if (sunscreenFrequency != null) {
      parts.add('선크림: ${sunscreenFrequencyLabel(sunscreenFrequency)}');
    }
    if (sunscreenReapply != null) {
      parts.add('재도포: ${sunscreenReapplyLabel(sunscreenReapply)}');
    }
    if (outdoorSportsUv != null) {
      parts.add('야외스포츠: ${outdoorSportsLabel(outdoorSportsUv)}');
    }
    return parts.isEmpty ? '미입력' : parts.join(', ');
  }

  static String drinkingSmokingSummary({
    required String? drinkingDaysPerWeek,
    required String? drinkingAmountPerSession,
    required String? smokingStatus,
    required String? smokingAmountUnit,
    required String smokingAmountText,
  }) {
    final parts = <String>[];
    if (drinkingDaysPerWeek != null) {
      parts.add('음주: ${drinkingDaysLabel(drinkingDaysPerWeek)}');
    }
    if (drinkingAmountPerSession != null &&
        drinkingAmountPerSession.isNotEmpty) {
      parts.add('1회량: $drinkingAmountPerSession');
    }
    if (smokingStatus != null) {
      final smokingLabel = smokingStatus == 'never'
          ? '안함'
          : (smokingStatus == 'former' ? '과거 흡연' : '현재 흡연');
      parts.add('흡연: $smokingLabel');
      if (smokingStatus == 'current' &&
          smokingAmountUnit != null &&
          smokingAmountText.isNotEmpty) {
        parts.add('$smokingAmountText$smokingAmountUnit');
      }
    }
    return parts.isEmpty ? '미입력' : parts.join(', ');
  }

  static String caffeineTimingLabel(String? value) {
    const map = {'before_noon': '오전', 'afternoon': '오후', 'evening': '저녁'};
    return map[value] ?? '';
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

  static String skinConcernLabel(String value) {
    const map = {
      'wrinkle': '주름',
      'pigmentation': '색소',
      'elasticity': '탄력',
      'dryness': '건조',
      'redness': '홍조',
      'acne': '트러블',
    };
    return map[value] ?? value;
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
    };
    return map[value] ?? value ?? '';
  }

  static String sunscreenReapplyLabel(String? value) {
    const map = {
      'never': '안함',
      'rarely': '드물게',
      'sometimes': '가끔',
      'often': '자주',
    };
    return map[value] ?? value ?? '';
  }

  static String outdoorSportsLabel(String? value) {
    const map = {'none': '안함', 'monthly': '월 1회', 'weekly': '주 1회 이상'};
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
