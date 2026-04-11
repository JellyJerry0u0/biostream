class ResultScreenMetrics {
  static int getCurrentAge(Map<String, dynamic>? lifestyleData) {
    if (lifestyleData?['profile']?['age'] != null) {
      final ageStr = lifestyleData!['profile']['age'].toString().split(' ')[0];
      return int.tryParse(ageStr) ?? 29;
    }
    return 29;
  }

  static int getTargetYears(Map<String, dynamic>? lifestyleData) {
    if (lifestyleData?['target_age'] != null) {
      final targetAgeStr = lifestyleData!['target_age'].toString();
      final match = RegExp(r'(\d+)').firstMatch(targetAgeStr);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '') ?? 30;
      }
    }
    return 30;
  }
}
