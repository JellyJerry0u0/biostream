import '../../services/lifestyle_service.dart';

class SurveyFormState {
  const SurveyFormState({
    required this.outcomes,
    required this.sleepHoursWeekday,
    required this.sleepHoursWeekend,
    required this.sleepQualityScore,
    required this.uvExposure10to16,
    required this.sunscreenFrequency,
    required this.sunscreenReapply,
    required this.outdoorSportsUv,
    required this.drinkingDaysPerWeek,
    required this.drinkingAmountPerSession,
    required this.smokingStatus,
    required this.smokingAmountPerDay,
    required this.stressScore,
    required this.caffeineIntake,
    required this.caffeineTiming,
    required this.aerobicWeekly,
    required this.resistanceWeekly,
    required this.height,
    required this.weight,
    required this.skinType,
    required this.skinConcerns,
    required this.skinSatisfaction,
    required this.targetYears,
    required this.originalImageUrl,
  });

  final List<String> outcomes;
  final double? sleepHoursWeekday;
  final double? sleepHoursWeekend;
  final double? sleepQualityScore;
  final String? uvExposure10to16;
  final String? sunscreenFrequency;
  final String? sunscreenReapply;
  final String? outdoorSportsUv;
  final String? drinkingDaysPerWeek;
  final String? drinkingAmountPerSession;
  final String? smokingStatus;
  final String? smokingAmountPerDay;
  final double? stressScore;
  final String? caffeineIntake;
  final String? caffeineTiming;
  final String? aerobicWeekly;
  final String? resistanceWeekly;
  final double? height;
  final double? weight;
  final String? skinType;
  final List<String> skinConcerns;
  final double? skinSatisfaction;
  final int targetYears;
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
      "sunscreen_reapply": state.sunscreenReapply,
      "outdoor_sports_uv": state.outdoorSportsUv,
      "drinking_days_per_week": state.drinkingDaysPerWeek,
      "drinking_amount_per_session": state.drinkingAmountPerSession,
      "smoking_status": state.smokingStatus,
      "smoking_amount_per_day": state.smokingAmountPerDay,
      "stress_score": state.stressScore,
      "caffeine_intake": state.caffeineIntake,
      "caffeine_timing": state.caffeineTiming,
      "aerobic_weekly": state.aerobicWeekly,
      "resistance_weekly": state.resistanceWeekly,
      "height": state.height,
      "weight": state.weight,
      "skin_type": state.skinType,
      "skin_concerns": state.skinConcerns,
      "skin_satisfaction": state.skinSatisfaction,
      "target_years": state.targetYears,
      if (state.originalImageUrl != null)
        "original_image_url": state.originalImageUrl,
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
