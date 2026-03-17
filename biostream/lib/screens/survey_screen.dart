import 'package:flutter/material.dart';
import '../services/lifestyle_service.dart';
import 'result/result_screen.dart';
import 'survey/survey_controller.dart';
import 'survey/survey_labels.dart';
import '../widgets/survey/common/survey_form_fields.dart';
import '../widgets/survey/pages/survey_activity_page.dart';
import '../widgets/survey/pages/survey_alcohol_smoking_page.dart';
import '../widgets/survey/pages/survey_outcomes_page.dart';
import '../widgets/survey/pages/survey_skin_page.dart';
import '../widgets/survey/pages/survey_sleep_page.dart';
import '../widgets/survey/pages/survey_stress_page.dart';
import '../widgets/survey/pages/survey_summary_page.dart';
import '../widgets/survey/pages/survey_target_years_page.dart';
import '../widgets/survey/pages/survey_uv_page.dart';
import '../widgets/survey/survey_progress_header.dart';
import '../widgets/survey/survey_swipe_hint.dart';

class SurveyScreen extends StatefulWidget {
  final String? originalImageUrl;
  final bool showHomeButtonOnFirstPage;

  const SurveyScreen({
    super.key,
    this.originalImageUrl,
    this.showHomeButtonOnFirstPage = false,
  });

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final PageController _pageController = PageController();
  final LifestyleService _lifestyleService = LifestyleService();
  late final SurveyController _surveyController;
  int _currentPage = 0;
  bool _showSwipeHint = true;

  // A. 주요 목표
  final List<String> _outcomes = [];

  // B. Sleep & Rhythm (기본값 설정 - 슬라이더 표시값이 자동으로 저장됨)
  double? _sleepHoursWeekday = 7.0; // 평균 수면시간 평일 기본값
  double? _sleepHoursWeekend = 7.0; // 평균 수면시간 주말 기본값
  double? _sleepQualityScore = 5.0; // 수면의 질 기본값

  // C. UV / Photoaging
  String? _uvExposure10to16;
  String? _sunscreenFrequency;
  String? _sunscreenReapply;
  String? _outdoorSportsUv;

  // D. Alcohol & Smoking
  String? _drinkingDaysPerWeek;
  String? _drinkingAmountPerSession;
  String? _smokingStatus;
  String? _smokingAmountUnit; // 갑/개비
  final TextEditingController _smokingAmountController =
      TextEditingController();

  // E. Stress & Recovery (기본값 설정)
  double? _stressScore = 5.0; // 스트레스 점수 기본값
  String? _caffeineIntake;
  String? _caffeineTiming;

  // F. Activity & Metabolic
  String? _aerobicWeekly;
  String? _resistanceWeekly;
  double? _height;
  double? _weight;

  // Skin 상태 (기본값 설정)
  String? _skinType;
  final List<String> _skinConcerns = [];
  double? _skinSatisfaction = 5.0; // 피부 만족도 기본값

  // 목표 연도
  double _targetYears = 30.0;

  // 참고할 상황 (선택, 마지막 입력, DB 저장 안 함)
  final TextEditingController _situationTextController =
      TextEditingController();
  static const int _situationTextMaxLength = 200;

  final int _totalPages = 9; // 8개 섹션 + 1개 요약

  @override
  void initState() {
    super.initState();
    _surveyController = SurveyController(lifestyleService: _lifestyleService);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _smokingAmountController.dispose();
    _situationTextController.dispose();
    super.dispose();
  }

  SurveyFormState _currentFormState() {
    return SurveyFormState(
      outcomes: _outcomes,
      sleepHoursWeekday: _sleepHoursWeekday,
      sleepHoursWeekend: _sleepHoursWeekend,
      sleepQualityScore: _sleepQualityScore,
      uvExposure10to16: _uvExposure10to16,
      sunscreenFrequency: _sunscreenFrequency,
      sunscreenReapply: _sunscreenReapply,
      outdoorSportsUv: _outdoorSportsUv,
      drinkingDaysPerWeek: _drinkingDaysPerWeek,
      drinkingAmountPerSession: _drinkingAmountPerSession,
      smokingStatus: _smokingStatus,
      smokingAmountPerDay:
          _smokingAmountUnit != null && _smokingAmountController.text.isNotEmpty
              ? "${_smokingAmountController.text}$_smokingAmountUnit"
              : null,
      stressScore: _stressScore,
      caffeineIntake: _caffeineIntake,
      caffeineTiming: _caffeineTiming,
      aerobicWeekly: _aerobicWeekly,
      resistanceWeekly: _resistanceWeekly,
      height: _height,
      weight: _weight,
      skinType: _skinType,
      skinConcerns: _skinConcerns,
      skinSatisfaction: _skinSatisfaction,
      targetYears: _targetYears.toInt(),
      originalImageUrl: widget.originalImageUrl,
    );
  }

  Future<void> _submitSurvey() async {
    debugPrint('[SurveyScreen] 설문 데이터 제출 시작');
    final result = await _surveyController.submitSurvey(_currentFormState());

    if (result.success && mounted) {
      final situationText = _situationTextController.text.trim();
      final situationForReport =
          situationText.isNotEmpty ? situationText : null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            situationText: situationForReport,
            originalImageUrl: widget.originalImageUrl,
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '저장에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainGoalsSummary = SurveyLabels.mainGoalsSummary(_outcomes);
    final sleepSummary =
        '평일: ${_sleepHoursWeekday!.toInt()}h, 주말: ${_sleepHoursWeekend!.toInt()}h, 질: ${_sleepQualityScore!.toInt()}점';
    final stressRecoverySummary =
        '스트레스: ${_stressScore!.toInt()}점, 카페인: ${_caffeineIntake ?? '미입력'}${_caffeineTiming != null ? ' (${SurveyLabels.caffeineTimingLabel(_caffeineTiming)})' : ''}';
    final activitySummary =
        '유산소: ${SurveyLabels.aerobicLabel(_aerobicWeekly)}, 근력: ${SurveyLabels.resistanceLabel(_resistanceWeekly)}, 키/몸무게: ${_height != null ? '${_height!.toInt()}cm' : '미입력'} / ${_weight != null ? '${_weight!.toInt()}kg' : '미입력'}';
    final skinSummary =
        '타입: ${SurveyLabels.skinTypeLabel(_skinType)}, 고민: ${_skinConcerns.isEmpty ? '없음' : _skinConcerns.map(SurveyLabels.skinConcernLabel).join(', ')}, 만족도: ${_skinSatisfaction!.toInt()}점';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            SurveyProgressHeader(
              isDark: isDark,
              currentPage: _currentPage,
              totalPages: _totalPages,
              showHomeButtonOnFirstPage: widget.showHomeButtonOnFirstPage,
              onJumpToSummary: () {
                _pageController.animateToPage(
                  _totalPages - 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            // PageView
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                        if (index > 0 && _showSwipeHint) {
                          _showSwipeHint = false;
                        }
                      });
                    },
                    children: [
                      SurveyOutcomesPage(
                        isDark: isDark,
                        outcomes: _outcomes,
                        onToggleOutcome: (value) {
                          setState(() {
                            if (_outcomes.contains(value)) {
                              _outcomes.remove(value);
                            } else {
                              _outcomes.add(value);
                            }
                          });
                        },
                        chipBuilder: _buildChip,
                      ),
                      SurveySleepPage(
                        isDark: isDark,
                        sleepHoursWeekday: _sleepHoursWeekday!,
                        sleepHoursWeekend: _sleepHoursWeekend!,
                        sleepQualityScore: _sleepQualityScore!,
                        onSleepHoursWeekdayChanged: (value) {
                          setState(() => _sleepHoursWeekday = value);
                        },
                        onSleepHoursWeekendChanged: (value) {
                          setState(() => _sleepHoursWeekend = value);
                        },
                        onSleepQualityScoreChanged: (value) {
                          setState(() => _sleepQualityScore = value);
                        },
                        sliderBuilder: _buildSliderField,
                      ),
                      SurveyUvPage(
                        isDark: isDark,
                        uvExposure10to16: _uvExposure10to16,
                        sunscreenFrequency: _sunscreenFrequency,
                        sunscreenReapply: _sunscreenReapply,
                        outdoorSportsUv: _outdoorSportsUv,
                        onUvExposureChanged: (value) {
                          setState(() => _uvExposure10to16 = value);
                        },
                        onSunscreenFrequencyChanged: (value) {
                          setState(() => _sunscreenFrequency = value);
                        },
                        onSunscreenReapplyChanged: (value) {
                          setState(() => _sunscreenReapply = value);
                        },
                        onOutdoorSportsUvChanged: (value) {
                          setState(() => _outdoorSportsUv = value);
                        },
                        choiceBuilder: _buildChoiceButton,
                      ),
                      SurveyAlcoholSmokingPage(
                        isDark: isDark,
                        drinkingDaysPerWeek: _drinkingDaysPerWeek,
                        drinkingAmountPerSession: _drinkingAmountPerSession,
                        smokingStatus: _smokingStatus,
                        smokingAmountUnit: _smokingAmountUnit,
                        smokingAmountController: _smokingAmountController,
                        onDrinkingDaysChanged: (value) {
                          setState(() => _drinkingDaysPerWeek = value);
                        },
                        onDrinkingAmountChanged: (value) {
                          setState(() => _drinkingAmountPerSession = value);
                        },
                        onSmokingStatusChanged: (value) {
                          setState(() {
                            _smokingStatus = value;
                            if (value != 'current') {
                              _smokingAmountUnit = null;
                              _smokingAmountController.clear();
                            }
                          });
                        },
                        onSmokingAmountUnitChanged: (value) {
                          setState(() => _smokingAmountUnit = value);
                        },
                        choiceBuilder: _buildChoiceButton,
                        textFieldBuilder: _buildTextField,
                        numberFieldBuilder: _buildNumberTextField,
                      ),
                      SurveyStressPage(
                        isDark: isDark,
                        stressScore: _stressScore!,
                        caffeineIntake: _caffeineIntake,
                        caffeineTiming: _caffeineTiming,
                        onStressScoreChanged: (value) {
                          setState(() => _stressScore = value);
                        },
                        onCaffeineIntakeChanged: (value) {
                          setState(() => _caffeineIntake = value);
                        },
                        onCaffeineTimingChanged: (value) {
                          setState(() => _caffeineTiming = value);
                        },
                        choiceBuilder: _buildChoiceButton,
                        sliderBuilder: _buildSliderField,
                      ),
                      SurveyActivityPage(
                        isDark: isDark,
                        aerobicWeekly: _aerobicWeekly,
                        resistanceWeekly: _resistanceWeekly,
                        height: _height,
                        weight: _weight,
                        onAerobicWeeklyChanged: (value) {
                          setState(() => _aerobicWeekly = value);
                        },
                        onResistanceWeeklyChanged: (value) {
                          setState(() => _resistanceWeekly = value);
                        },
                        onHeightChanged: (value) {
                          setState(() => _height = value?.toDouble());
                        },
                        onWeightChanged: (value) {
                          setState(() => _weight = value?.toDouble());
                        },
                        choiceBuilder: _buildChoiceButton,
                        integerFieldBuilder: _buildIntegerTextField,
                      ),
                      SurveySkinPage(
                        isDark: isDark,
                        skinType: _skinType,
                        skinConcerns: _skinConcerns,
                        skinSatisfaction: _skinSatisfaction!,
                        onSkinTypeChanged: (value) {
                          setState(() => _skinType = value);
                        },
                        onSkinConcernToggled: (value) {
                          setState(() {
                            if (_skinConcerns.contains(value)) {
                              _skinConcerns.remove(value);
                            } else {
                              _skinConcerns.add(value);
                            }
                          });
                        },
                        onSkinSatisfactionChanged: (value) {
                          setState(() => _skinSatisfaction = value);
                        },
                        choiceBuilder: _buildChoiceButton,
                        chipBuilder: _buildChip,
                        sliderBuilder: _buildSliderField,
                      ),
                      SurveyTargetYearsPage(
                        isDark: isDark,
                        targetYears: _targetYears,
                        onTargetYearsChanged: (value) {
                          setState(() => _targetYears = value);
                        },
                      ),
                      SurveySummaryPage(
                        isDark: isDark,
                        situationController: _situationTextController,
                        situationTextMaxLength: _situationTextMaxLength,
                        mainGoalsSummary: mainGoalsSummary,
                        sleepSummary: sleepSummary,
                        uvSummary: SurveyLabels.uvExposureSummary(
                          uvExposure10to16: _uvExposure10to16,
                          sunscreenFrequency: _sunscreenFrequency,
                          sunscreenReapply: _sunscreenReapply,
                          outdoorSportsUv: _outdoorSportsUv,
                        ),
                        drinkingSmokingSummary:
                            SurveyLabels.drinkingSmokingSummary(
                          drinkingDaysPerWeek: _drinkingDaysPerWeek,
                          drinkingAmountPerSession: _drinkingAmountPerSession,
                          smokingStatus: _smokingStatus,
                          smokingAmountUnit: _smokingAmountUnit,
                          smokingAmountText: _smokingAmountController.text,
                        ),
                        stressRecoverySummary: stressRecoverySummary,
                        activitySummary: activitySummary,
                        skinSummary: skinSummary,
                        targetYearsSummary: '+${_targetYears.toInt()}년 후',
                        onSubmit: _submitSurvey,
                      ),
                    ],
                  ),
                  // Swipe Hint
                  if (_showSwipeHint && _currentPage == 0)
                    SurveySwipeHint(
                      isDark: isDark,
                      onDismiss: () {
                        setState(() {
                          _showSwipeHint = false;
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
      {required String label,
      required bool isSelected,
      required VoidCallback onTap,
      required bool isDark}) {
    return SurveyFormFields.chip(
      context: context,
      label: label,
      isSelected: isSelected,
      onTap: onTap,
      isDark: isDark,
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
    required bool isDark,
    bool isInteger = false,
  }) {
    return SurveyFormFields.sliderField(
      context: context,
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      suffix: suffix,
      onChanged: onChanged,
      isDark: isDark,
      isInteger: isInteger,
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return SurveyFormFields.choiceButton(
      context: context,
      label: label,
      isSelected: isSelected,
      onTap: onTap,
      isDark: isDark,
    );
  }

  Widget _buildTextField({
    required String label,
    required String? value,
    required String placeholder,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SurveyFormFields.textField(
      label: label,
      value: value,
      placeholder: placeholder,
      onChanged: onChanged,
      isDark: isDark,
      keyboardType: keyboardType,
    );
  }

  Widget _buildIntegerTextField({
    required String label,
    required int? value,
    required String placeholder,
    required ValueChanged<int?> onChanged,
    required bool isDark,
  }) {
    return SurveyFormFields.integerTextField(
      label: label,
      value: value,
      placeholder: placeholder,
      onChanged: onChanged,
      isDark: isDark,
    );
  }

  Widget _buildNumberTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required String suffix,
    required bool isDark,
  }) {
    return SurveyFormFields.numberTextField(
      context: context,
      label: label,
      controller: controller,
      placeholder: placeholder,
      suffix: suffix,
      isDark: isDark,
    );
  }
}
