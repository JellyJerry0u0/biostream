import '../../services/lifestyle_service.dart';

class SurveyFormState {
  const SurveyFormState({
    this.lifestyleId,
    required this.outcomes,
    required this.sleepHoursWeekday,
    required this.sleepHoursWeekend,
    required this.sleepQualityScore,
    required this.uvExposure10to16,
    required this.sunscreenFrequency,
    required this.drinkingDaysPerWeek,
    required this.smokingStatus,
    required this.smokingDaysPerWeek,
    required this.stressScore,
    required this.aerobicWeekly,
    required this.resistanceWeekly,
    required this.height,
    required this.weight,
    required this.skinType,
    required this.skinSatisfaction,
    required this.originalImageUrl,
  });

  /// /data/upload 직후 받은 ID — 있으면 같은 lifestyle 행에 설문만 갱신
  final int? lifestyleId;
  final List<String> outcomes;
  final double? sleepHoursWeekday;
  final double? sleepHoursWeekend;
  final double? sleepQualityScore;
  final String? uvExposure10to16;
  final String? sunscreenFrequency;
  final String? drinkingDaysPerWeek;
  final String? smokingStatus;
  final String? smokingDaysPerWeek;
  final double? stressScore;
  final String? aerobicWeekly;
  final String? resistanceWeekly;
  final double? height;
  final double? weight;
  final String? skinType;
  final double? skinSatisfaction;
  final String? originalImageUrl;
}

class SurveySubmitResult {
  const SurveySubmitResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class SurveyController {
  SurveyController({required LifestyleService lifestyleService})
      : _lifestyleService = lifestyleService;

  final LifestyleService _lifestyleService;

  Map<String, dynamic> buildLifestyleData(SurveyFormState state) {
    return {
      "outcomes": state.outcomes,
      "sleep_hours_weekday": state.sleepHoursWeekday,
      "sleep_hours_weekend": state.sleepHoursWeekend,
      "sleep_quality_score": state.sleepQualityScore,
      "uv_exposure_10to16": state.uvExposure10to16,
      "sunscreen_frequency": state.sunscreenFrequency,
      "drinking_days_per_week": state.drinkingDaysPerWeek,
      "drinking_amount_per_session": null,
      "smoking_status": state.smokingStatus,
      "smoking_amount_per_day": null,
      "smoking_days_per_week": state.smokingDaysPerWeek,
      "stress_score": state.stressScore,
      "aerobic_weekly": state.aerobicWeekly,
      "resistance_weekly": state.resistanceWeekly,
      "height": state.height,
      "weight": state.weight,
      "skin_type": state.skinType,
      "skin_satisfaction": state.skinSatisfaction,
      "target_years": 30,
      if (state.originalImageUrl != null)
        "original_image_url": state.originalImageUrl,
      if (state.lifestyleId != null) "lifestyle_id": state.lifestyleId,
    };
  }

  Future<SurveySubmitResult> submitSurvey(SurveyFormState state) async {
    final lifestyleData = buildLifestyleData(state);
    final result = await _lifestyleService.saveLifestyleProfile(lifestyleData);
    if (result['success'] == true) {
      return const SurveySubmitResult(success: true);
    }
    return SurveySubmitResult(
      success: false,
      message: result['message']?.toString() ?? '저장에 실패했습니다.',
    );
  }
}
