import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import '../services/lifestyle_service.dart';
import 'result_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final LifestyleService _lifestyleService = LifestyleService();

  // Form controllers - 흡연
  String _smokingStatus = '비흡연'; // 비흡연/과거 흡연/현재 흡연
  final TextEditingController _smokingAmountController = TextEditingController();
  final TextEditingController _smokingDurationController = TextEditingController();

  // Form controllers - 운동
  final TextEditingController _exerciseDailyMinsController = TextEditingController();
  final TextEditingController _exerciseFreqPerWeekController = TextEditingController();
  String _exerciseIntensity = '중강도'; // 저강도/중강도/고강도
  String _exerciseType = '안함'; // 유산소/무산소/기타/안함
  final TextEditingController _exerciseTypeOtherController = TextEditingController();
  final TextEditingController _sedentaryHoursPerDayController = TextEditingController();
  String _exerciseRegularity = '규칙적'; // 규칙적/불규칙적
  final TextEditingController _exerciseDurationYearsController = TextEditingController();
  bool _stretchingHabit = false;
  String _exerciseLocation = '실내'; // 실내/실외/혼합

  // Form controllers - 수면
  final TextEditingController _sleepHoursController = TextEditingController();
  String _sleepQuality = '보통'; // 매우 좋음/좋음/보통/나쁨/매우 나쁨
  String _sleepDisorders = '무'; // 무/코골이/수면무호흡증/불면증/기타
  String _sleepConsistency = '규칙적'; // 규칙적/불규칙적

  // Form controllers - 음주
  String _drinkingFrequency = '비음주'; // 비음주/가끔/주1-2회/주3-4회/매일/기타
  final List<Map<String, dynamic>> _drinkingDetails = []; // [{type: "소주", glass: "소주잔", count: 5}]
  final TextEditingController _drinkingTypeController = TextEditingController();
  final TextEditingController _drinkingGlassController = TextEditingController();
  final TextEditingController _drinkingCountController = TextEditingController();
  bool _facialFlushing = false;
  final TextEditingController _drinkingDurationYearsController = TextEditingController();

  // Form controllers - 야외 활동
  final List<Map<String, String>> _uvActivityHours = []; // [{start: "12:00", end: "12:30"}]
  final TextEditingController _outdoorStartController = TextEditingController();
  final TextEditingController _outdoorEndController = TextEditingController();
  String _sunscreenUsage = '가끔'; // 매일/가끔/안함
  final TextEditingController _sunscreenReapplyIntervalController = TextEditingController(); // 선크림 재도포 주기

  // Form controllers - 체성분 (선택적)
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _muscleMassController = TextEditingController();
  final TextEditingController _bodyFatMassController = TextEditingController();
  final TextEditingController _bodyFatPercentageController = TextEditingController();
  final TextEditingController _bmiController = TextEditingController();
  final TextEditingController _bmrController = TextEditingController();
  final TextEditingController _whrController = TextEditingController();
  final TextEditingController _bodyWaterController = TextEditingController();
  final TextEditingController _visceralFatLevelController = TextEditingController();

  // 목표 연도
  double _targetYears = 30.0;

  @override
  void dispose() {
    _smokingAmountController.dispose();
    _smokingDurationController.dispose();
    _exerciseDailyMinsController.dispose();
    _exerciseFreqPerWeekController.dispose();
    _exerciseTypeOtherController.dispose();
    _sedentaryHoursPerDayController.dispose();
    _exerciseDurationYearsController.dispose();
    _sleepHoursController.dispose();
    _drinkingTypeController.dispose();
    _drinkingGlassController.dispose();
    _drinkingCountController.dispose();
    _drinkingDurationYearsController.dispose();
    _outdoorStartController.dispose();
    _outdoorEndController.dispose();
    _sunscreenReapplyIntervalController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _muscleMassController.dispose();
    _bodyFatMassController.dispose();
    _bodyFatPercentageController.dispose();
    _bmiController.dispose();
    _bmrController.dispose();
    _whrController.dispose();
    _bodyWaterController.dispose();
    _visceralFatLevelController.dispose();
    super.dispose();
  }

  void _onBack() {
    Navigator.of(context).pop();
  }

  void _onSkip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ResultScreen()),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필수 항목을 입력해주세요.')),
      );
      return;
    }

    // 데이터 검증
    if (_smokingStatus != '비흡연' && _smokingAmountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('흡연량을 입력해주세요.')),
      );
      return;
    }

    // JSON 형식으로 음주 상세 정보 변환
    List<Map<String, dynamic>>? drinkingDetailsJson = null;
    if (_drinkingDetails.isNotEmpty) {
      drinkingDetailsJson = _drinkingDetails;
    }

    // JSON 형식으로 자외선 노출 시간대 변환
    List<String> uvActivityHoursJson = _uvActivityHours.map((time) {
      return '${time['start']}~${time['end']}';
    }).toList();

    // 데이터 구조화
    final lifestyleData = {
      "smoking_status": _smokingStatus,
      "smoking_amount": _smokingStatus != '비흡연' ? int.tryParse(_smokingAmountController.text) : null,
      "smoking_duration": _smokingStatus != '비흡연' ? int.tryParse(_smokingDurationController.text) : null,
      "exercise_daily_mins": int.tryParse(_exerciseDailyMinsController.text) ?? 0,
      "exercise_freq_per_week": int.tryParse(_exerciseFreqPerWeekController.text) ?? 0,
      "exercise_intensity": _exerciseIntensity,
      "exercise_type": _exerciseType == '기타' ? _exerciseTypeOtherController.text : _exerciseType,
      "sedentary_hours_per_day": double.tryParse(_sedentaryHoursPerDayController.text) ?? 0.0,
      "exercise_regularity": _exerciseRegularity,
      "exercise_duration_years": int.tryParse(_exerciseDurationYearsController.text) ?? 0,
      "stretching_habit": _stretchingHabit,
      "excercise_location": _exerciseLocation,
      "sleep_hours": double.tryParse(_sleepHoursController.text) ?? 0.0,
      "sleep_quality": _sleepQuality,
      "sleep_disorders": _sleepDisorders,
      "sleep_consistency": _sleepConsistency,
      "drinking_frequency": _drinkingFrequency,
      "drinking_details": drinkingDetailsJson,
      "facial_flushing": _facialFlushing,
      "drinking_duration_years": int.tryParse(_drinkingDurationYearsController.text),
      "uv_actuvity_hours": uvActivityHoursJson,
      "sunscreen_usage": _sunscreenUsage,
      "sunscreen_reapply_interval": _sunscreenReapplyIntervalController.text.isNotEmpty ? _sunscreenReapplyIntervalController.text : null,
      "weight": _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
      "height": _heightController.text.isNotEmpty ? double.tryParse(_heightController.text) : null,
      "muscle_mass": _muscleMassController.text.isNotEmpty ? double.tryParse(_muscleMassController.text) : null,
      "body_fat_mass": _bodyFatMassController.text.isNotEmpty ? double.tryParse(_bodyFatMassController.text) : null,
      "body_fat_percentage": _bodyFatPercentageController.text.isNotEmpty ? double.tryParse(_bodyFatPercentageController.text) : null,
      "bmi": _bmiController.text.isNotEmpty ? double.tryParse(_bmiController.text) : null,
      "bmr": _bmrController.text.isNotEmpty ? double.tryParse(_bmrController.text) : null,
      "whr": _whrController.text.isNotEmpty ? double.tryParse(_whrController.text) : null,
      "body_water": _bodyWaterController.text.isNotEmpty ? double.tryParse(_bodyWaterController.text) : null,
      "visceral_fat_level": _visceralFatLevelController.text.isNotEmpty ? double.tryParse(_visceralFatLevelController.text) : null,
      "target_years": _targetYears.toInt(),
    };

    // API 호출
    final result = await _lifestyleService.saveLifestyleProfile(lifestyleData);
    
    if (result['success'] == true) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ResultScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? '저장에 실패했습니다.')),
        );
      }
    }
  }


  void _addOutdoorTime() {
    final start = _outdoorStartController.text.isEmpty ? '08:00' : _outdoorStartController.text;
    final end = _outdoorEndController.text.isEmpty ? '09:00' : _outdoorEndController.text;

    setState(() {
      _uvActivityHours.add({'start': start, 'end': end});
      _outdoorStartController.clear();
      _outdoorEndController.clear();
    });
  }

  void _removeOutdoorTime(int index) {
    setState(() {
      _uvActivityHours.removeAt(index);
    });
  }

  void _addDrinkingDetail() {
    if (_drinkingTypeController.text.isEmpty || _drinkingCountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음주 종류와 수량을 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _drinkingDetails.add({
        'type': _drinkingTypeController.text,
        'glass': _drinkingGlassController.text.isEmpty ? '잔' : _drinkingGlassController.text,
        'count': int.tryParse(_drinkingCountController.text) ?? 0,
      });
      _drinkingTypeController.clear();
      _drinkingGlassController.clear();
      _drinkingCountController.clear();
    });
  }

  void _removeDrinkingDetail(int index) {
    setState(() {
      _drinkingDetails.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 24);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: Responsive.padding(context, 12),
                ),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
                      .withOpacity(0.9),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _onBack,
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          width: Responsive.fontSize(context, 40),
                          height: Responsive.fontSize(context, 40),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back,
                            size: Responsive.iconSize(context, 24),
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '생활 습관 설문',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    TextButton(
                      onPressed: _onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF37EC13),
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.padding(context, 8),
                        ),
                      ),
                      child: Text(
                        '건너뛰기',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress Bar
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: Responsive.padding(context, 16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step 2 of 3',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 10),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF37EC13),
                          ),
                        ),
                        Text(
                          '상세 정보 입력',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 10),
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.padding(context, 8)),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: Responsive.fontSize(context, 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF37EC13),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.padding(context, 8)),
                        Expanded(
                          child: Container(
                            height: Responsive.fontSize(context, 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF37EC13),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.padding(context, 8)),
                        Expanded(
                          child: Container(
                            height: Responsive.fontSize(context, 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : const Color(0xFF37EC13).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: Responsive.padding(context, 24)),

                      // Title Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '정확한 분석을 위해\n생활 습관을 알려주세요',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 26),
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          SizedBox(height: Responsive.padding(context, 8)),
                          Text(
                            '입력하신 데이터를 기반으로 현재 노화 상태와\n미래 피부 변화를 정밀하게 예측합니다.',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 14),
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: Responsive.padding(context, 24)),

                      // 흡연 습관 섹션
                      _SectionCard(
                        title: '흡연 습관',
                        icon: Icons.smoking_rooms,
                        isDark: isDark,
                        child: Column(
                          children: [
                            _RadioGroup(
                              options: ['비흡연', '과거 흡연', '현재 흡연'],
                              selected: _smokingStatus == '비흡연' ? 0 : (_smokingStatus == '과거 흡연' ? 1 : 2),
                              onChanged: (index) {
                                setState(() {
                                  _smokingStatus = index == 0 ? '비흡연' : (index == 1 ? '과거 흡연' : '현재 흡연');
                                });
                              },
                              isDark: isDark,
                              isHorizontal: true,
                              isThreeOptions: true,
                            ),
                            if (_smokingStatus != '비흡연') ...[
                              SizedBox(height: Responsive.padding(context, 16)),
                              Container(
                                height: 1,
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey[200],
                              ),
                              SizedBox(height: Responsive.padding(context, 16)),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InputField(
                                      label: '하루 흡연량',
                                      controller: _smokingAmountController,
                                      placeholder: '0',
                                      suffix: '개비',
                                      isDark: isDark,
                                      keyboardType: TextInputType.number,
                                      isSmall: true,
                                    ),
                                  ),
                                  SizedBox(width: Responsive.padding(context, 16)),
                                  Expanded(
                                    child: _InputField(
                                      label: '흡연 기간',
                                      controller: _smokingDurationController,
                                      placeholder: '0',
                                      suffix: '년',
                                      isDark: isDark,
                                      keyboardType: TextInputType.number,
                                      isSmall: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.padding(context, 16)),

                      // 운동 습관 섹션
                      _SectionCard(
                        title: '운동 습관',
                        icon: Icons.fitness_center,
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: '하루 평균 운동 시간',
                                    controller: _exerciseDailyMinsController,
                                    placeholder: '0',
                                    suffix: '분',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                                SizedBox(width: Responsive.padding(context, 8)),
                                Expanded(
                                  child: _InputField(
                                    label: '주당 운동 빈도',
                                    controller: _exerciseFreqPerWeekController,
                                    placeholder: '0',
                                    suffix: '회',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _LabeledDropdown(
                              label: '운동 강도',
                              value: _exerciseIntensity,
                              items: ['저강도', '중강도', '고강도'],
                              onChanged: (value) {
                                setState(() {
                                  _exerciseIntensity = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _LabeledDropdown(
                              label: '운동 종류',
                              value: _exerciseType,
                              items: ['유산소', '무산소', '기타', '안함'],
                              onChanged: (value) {
                                setState(() {
                                  _exerciseType = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                            if (_exerciseType == '기타') ...[
                              SizedBox(height: Responsive.padding(context, 12)),
                              _InputField(
                                label: '운동 종류 (직접 입력)',
                                controller: _exerciseTypeOtherController,
                                placeholder: '예: 수영, 복합 운동',
                                suffix: '',
                                isDark: isDark,
                                keyboardType: TextInputType.text,
                                isSmall: true,
                              ),
                            ],
                            SizedBox(height: Responsive.padding(context, 16)),
                            _InputField(
                              label: '하루 평균 앉아있는 시간',
                              controller: _sedentaryHoursPerDayController,
                              placeholder: '0',
                              suffix: '시간',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              isSmall: true,
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _LabeledDropdown(
                              label: '운동 규칙성',
                              value: _exerciseRegularity,
                              items: ['규칙적', '불규칙적'],
                              onChanged: (value) {
                                setState(() {
                                  _exerciseRegularity = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _InputField(
                              label: '운동 지속 기간',
                              controller: _exerciseDurationYearsController,
                              placeholder: '0',
                              suffix: '년',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              isSmall: true,
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            Row(
                              children: [
                                Text(
                                  '스트레칭 습관',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                const Spacer(),
                                _Switch(
                                  value: _stretchingHabit,
                                  onChanged: (value) {
                                    setState(() {
                                      _stretchingHabit = value;
                                    });
                                  },
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _LabeledDropdown(
                              label: '주로 운동하는 장소',
                              value: _exerciseLocation,
                              items: ['실내', '실외', '혼합'],
                              onChanged: (value) {
                                setState(() {
                                  _exerciseLocation = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.padding(context, 16)),

                      // 수면 습관 섹션
                      _SectionCard(
                        title: '수면 습관',
                        icon: Icons.bedtime,
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InputField(
                              label: '평균 수면 시간',
                              controller: _sleepHoursController,
                              placeholder: '7',
                              suffix: '시간',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              isSmall: true,
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _LabeledDropdown(
                              label: '수면의 질',
                              value: _sleepQuality,
                              items: ['매우 좋음', '좋음', '보통', '나쁨', '매우 나쁨'],
                              onChanged: (value) {
                                setState(() {
                                  _sleepQuality = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _LabeledDropdown(
                              label: '수면 장애 여부',
                              value: _sleepDisorders,
                              items: ['무', '코골이', '수면무호흡증', '불면증', '기타'],
                              onChanged: (value) {
                                setState(() {
                                  _sleepDisorders = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _LabeledDropdown(
                              label: '수면 패턴 일관성',
                              value: _sleepConsistency,
                              items: ['규칙적', '불규칙적'],
                              onChanged: (value) {
                                setState(() {
                                  _sleepConsistency = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.padding(context, 16)),

                      // 음주 습관 섹션
                      _SectionCard(
                        title: '음주 습관',
                        icon: Icons.wine_bar,
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LabeledDropdown(
                              label: '음주 빈도',
                              value: _drinkingFrequency,
                              items: ['비음주', '가끔', '주1-2회', '주3-4회', '매일', '기타'],
                              onChanged: (value) {
                                setState(() {
                                  _drinkingFrequency = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                            if (_drinkingFrequency != '비음주') ...[
                              SizedBox(height: Responsive.padding(context, 16)),
                              Container(
                                height: 1,
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey[200],
                              ),
                              SizedBox(height: Responsive.padding(context, 16)),
                              Text(
                                '1회 음주 시 평균 음주량',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 10),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: Responsive.padding(context, 8)),
                              if (_drinkingDetails.isNotEmpty) ...[
                                ...List.generate(_drinkingDetails.length, (index) {
                                  return Container(
                                    margin: EdgeInsets.only(bottom: Responsive.padding(context, 8)),
                                    padding: EdgeInsets.all(Responsive.padding(context, 12)),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${_drinkingDetails[index]['type']} ${_drinkingDetails[index]['glass']} ${_drinkingDetails[index]['count']}개',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(context, 14),
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _removeDrinkingDetail(index),
                                          icon: Icon(
                                            Icons.close,
                                            size: Responsive.iconSize(context, 18),
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                SizedBox(height: Responsive.padding(context, 8)),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: _InputField(
                                      label: '종류',
                                      controller: _drinkingTypeController,
                                      placeholder: '소주',
                                      suffix: '',
                                      isDark: isDark,
                                      keyboardType: TextInputType.text,
                                      isSmall: true,
                                    ),
                                  ),
                                  SizedBox(width: Responsive.padding(context, 8)),
                                  Expanded(
                                    child: _InputField(
                                      label: '잔',
                                      controller: _drinkingGlassController,
                                      placeholder: '소주잔',
                                      suffix: '',
                                      isDark: isDark,
                                      keyboardType: TextInputType.text,
                                      isSmall: true,
                                    ),
                                  ),
                                  SizedBox(width: Responsive.padding(context, 8)),
                                  Expanded(
                                    child: _InputField(
                                      label: '수량',
                                      controller: _drinkingCountController,
                                      placeholder: '5',
                                      suffix: '개',
                                      isDark: isDark,
                                      keyboardType: TextInputType.number,
                                      isSmall: true,
                                    ),
                                  ),
                                  SizedBox(width: Responsive.padding(context, 8)),
                                  Material(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: _addDrinkingDetail,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: Responsive.fontSize(context, 42),
                                        height: Responsive.fontSize(context, 42),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.add,
                                          color: isDark ? Colors.white : Colors.black87,
                                          size: Responsive.iconSize(context, 20),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.padding(context, 16)),
                              Row(
                                children: [
                                  Text(
                                    '음주 시 안면 홍조',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 10),
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  const Spacer(),
                                  _Switch(
                                    value: _facialFlushing,
                                    onChanged: (value) {
                                      setState(() {
                                        _facialFlushing = value;
                                      });
                                    },
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.padding(context, 16)),
                              _InputField(
                                label: '음주 경력',
                                controller: _drinkingDurationYearsController,
                                placeholder: '0',
                                suffix: '년',
                                isDark: isDark,
                                keyboardType: TextInputType.number,
                                isSmall: true,
                              ),
                            ],
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.padding(context, 16)),

                      // 야외 활동 및 자외선 섹션
                      _SectionCard(
                        title: '야외 활동 및 자외선',
                        icon: Icons.sunny,
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '야외 활동 시간',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 10),
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: Responsive.padding(context, 8)),
                            if (_uvActivityHours.isNotEmpty) ...[
                              ...List.generate(_uvActivityHours.length, (index) {
                                return Container(
                                  margin: EdgeInsets.only(bottom: Responsive.padding(context, 8)),
                                  padding: EdgeInsets.all(Responsive.padding(context, 12)),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: Responsive.fontSize(context, 32),
                                        height: Responsive.fontSize(context, 32),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1A2C16) : Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.schedule,
                                          size: Responsive.iconSize(context, 14),
                                          color: const Color(0xFF37EC13),
                                        ),
                                      ),
                                      SizedBox(width: Responsive.padding(context, 12)),
                                      Expanded(
                                        child: Text(
                                          '${_uvActivityHours[index]['start']} ~ ${_uvActivityHours[index]['end']}',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(context, 14),
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _removeOutdoorTime(index),
                                        icon: Icon(
                                          Icons.close,
                                          size: Responsive.iconSize(context, 18),
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              SizedBox(height: Responsive.padding(context, 12)),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: _TimeInputField(
                                          controller: _outdoorStartController,
                                          label: 'Start',
                                          isDark: isDark,
                                        ),
                                      ),
                                      SizedBox(width: Responsive.padding(context, 8)),
                                      Expanded(
                                        child: _TimeInputField(
                                          controller: _outdoorEndController,
                                          label: 'End',
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: Responsive.padding(context, 8)),
                                Material(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: _addOutdoorTime,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: Responsive.fontSize(context, 42),
                                      height: Responsive.fontSize(context, 42),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.add,
                                        color: isDark ? Colors.white : Colors.black87,
                                        size: Responsive.iconSize(context, 20),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 8)),
                            Text(
                              '*출퇴근, 점심시간 등 야외에 있는 시간을 모두 추가해주세요.',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 10),
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            Container(
                              height: 1,
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[200],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _LabeledDropdown(
                              label: '선크림 사용 빈도',
                              value: _sunscreenUsage,
                              items: ['매일', '가끔', '안함'],
                              onChanged: (value) {
                                setState(() {
                                  _sunscreenUsage = value!;
                                });
                              },
                              isDark: isDark,
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            _InputField(
                              label: '선크림 재도포 주기',
                              controller: _sunscreenReapplyIntervalController,
                              placeholder: '예: 2시간마다',
                              suffix: '',
                              isDark: isDark,
                              keyboardType: TextInputType.text,
                              isSmall: true,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.padding(context, 16)),

                      // 체성분 데이터 섹션 (선택적)
                      _SectionCard(
                        title: '체성분 데이터 (선택)',
                        icon: Icons.monitor_weight,
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: '체중',
                                    controller: _weightController,
                                    placeholder: '60',
                                    suffix: 'kg',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                                SizedBox(width: Responsive.padding(context, 16)),
                                Expanded(
                                  child: _InputField(
                                    label: '키',
                                    controller: _heightController,
                                    placeholder: '170',
                                    suffix: 'cm',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: '골격근량',
                                    controller: _muscleMassController,
                                    placeholder: '0',
                                    suffix: 'kg',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                                SizedBox(width: Responsive.padding(context, 16)),
                                Expanded(
                                  child: _InputField(
                                    label: '체지방량',
                                    controller: _bodyFatMassController,
                                    placeholder: '0',
                                    suffix: 'kg',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: '체지방률',
                                    controller: _bodyFatPercentageController,
                                    placeholder: '0',
                                    suffix: '%',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                                SizedBox(width: Responsive.padding(context, 16)),
                                Expanded(
                                  child: _InputField(
                                    label: 'BMI',
                                    controller: _bmiController,
                                    placeholder: '0',
                                    suffix: '',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: '기초대사량',
                                    controller: _bmrController,
                                    placeholder: '0',
                                    suffix: 'kcal',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                                SizedBox(width: Responsive.padding(context, 16)),
                                Expanded(
                                  child: _InputField(
                                    label: '복부지방률',
                                    controller: _whrController,
                                    placeholder: '0',
                                    suffix: '',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: '체수분량',
                                    controller: _bodyWaterController,
                                    placeholder: '0',
                                    suffix: 'kg',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                                SizedBox(width: Responsive.padding(context, 16)),
                                Expanded(
                                  child: _InputField(
                                    label: '내장지방레벨',
                                    controller: _visceralFatLevelController,
                                    placeholder: '0',
                                    suffix: '',
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    isSmall: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.padding(context, 16)),

                      // 목표 미래 나이 섹션
                      _SectionCard(
                        title: '목표 미래 나이',
                        icon: Icons.timelapse,
                        isDark: isDark,
                        showBadge: true,
                        badgeText: '+${_targetYears.toInt()}년 후',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI 모델이 예측할 미래 시점을 선택하세요.',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: Responsive.padding(context, 16)),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF37EC13),
                                inactiveTrackColor: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : const Color(0xFFD3E7CF),
                                thumbColor: const Color(0xFF37EC13),
                                thumbShape: RoundSliderThumbShape(
                                  enabledThumbRadius: Responsive.fontSize(context, 12),
                                ),
                                overlayShape: RoundSliderOverlayShape(
                                  overlayRadius: Responsive.fontSize(context, 20),
                                ),
                                overlayColor: const Color(0xFF37EC13).withOpacity(0.2),
                              ),
                              child: Slider(
                                value: _targetYears,
                                min: 10,
                                max: 50,
                                divisions: 4,
                                label: '+${_targetYears.toInt()}년',
                                onChanged: (value) {
                                  setState(() {
                                    _targetYears = value;
                                  });
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '+10년',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '+20년',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '+30년',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF37EC13),
                                  ),
                                ),
                                Text(
                                  '+40년',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  '+50년',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.padding(context, 100)),
                    ],
                  ),
                ),
              ),

              // Fixed Bottom Button
              Container(
                padding: EdgeInsets.all(horizontalPadding),
                color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: Responsive.fontSize(context, 56),
                    child: ElevatedButton(
                      onPressed: _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF37EC13),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '결과 분석하기',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 18),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: Responsive.padding(context, 8)),
                          Icon(
                            Icons.arrow_forward,
                            size: Responsive.iconSize(context, 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Section Card Widget
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool isDark;
  final bool showBadge;
  final String? badgeText;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.isDark,
    this.showBadge = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2C16) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: Responsive.iconSize(context, 20),
                color: Colors.grey[400],
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (showBadge && badgeText != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 12),
                    vertical: Responsive.padding(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF37EC13).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: const Color(0xFF37EC13).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 10),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF37EC13),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          child,
        ],
      ),
    );
  }
}

// Input Field Widget
class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final String suffix;
  final bool isDark;
  final TextInputType keyboardType;
  final bool isSmall;

  const _InputField({
    required this.label,
    required this.controller,
    required this.placeholder,
    required this.suffix,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.padding(context, 4),
            bottom: Responsive.padding(context, 4),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: isSmall
                  ? Responsive.fontSize(context, 10)
                  : Responsive.fontSize(context, 10),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.center,
              inputFormatters: keyboardType == TextInputType.number
                  ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))]
                  : null,
              style: TextStyle(
                fontSize: isSmall
                    ? Responsive.fontSize(context, 14)
                    : Responsive.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
                  borderSide: const BorderSide(
                    color: Color(0xFF37EC13),
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 16),
                  vertical: isSmall
                      ? Responsive.padding(context, 10)
                      : Responsive.padding(context, 12),
                ),
              ),
            ),
            if (suffix.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  right: Responsive.padding(context, 12),
                ),
                child: Text(
                  suffix,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 10),
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// Time Input Field Widget
class _TimeInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;

  const _TimeInputField({
    required this.controller,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.padding(context, 8),
            bottom: Responsive.padding(context, 4),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 10),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        SizedBox(
          height: Responsive.fontSize(context, 42),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: '00:00',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF37EC13),
                  width: 1,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 12),
                vertical: Responsive.padding(context, 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Labeled Dropdown Widget
class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Function(String?) onChanged;
  final bool isDark;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: Responsive.padding(context, 4),
            bottom: Responsive.padding(context, 4),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 10),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 16),
            vertical: Responsive.padding(context, 4),
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: Container(),
            dropdownColor: isDark ? const Color(0xFF1A2C16) : Colors.white,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
            icon: Icon(
              Icons.arrow_drop_down,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}

// Switch Widget
class _Switch extends StatelessWidget {
  final bool value;
  final Function(bool) onChanged;
  final bool isDark;

  const _Switch({
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF37EC13),
      activeTrackColor: const Color(0xFF37EC13).withOpacity(0.5),
      inactiveThumbColor: isDark ? Colors.grey[600] : Colors.grey[400],
      inactiveTrackColor: isDark
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.1),
    );
  }
}

// Radio Group Widget
class _RadioGroup extends StatelessWidget {
  final List<String> options;
  final int selected;
  final Function(int) onChanged;
  final bool isDark;
  final bool isHorizontal;
  final bool isThreeOptions;

  const _RadioGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.isDark,
    this.isHorizontal = false,
    this.isThreeOptions = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return Row(
        children: List.generate(options.length, (index) {
          return Expanded(
            child: _RadioOption(
              label: options[index],
              isSelected: selected == index,
              onTap: () => onChanged(index),
              isDark: isDark,
              isSmall: isThreeOptions,
            ),
          );
        }),
      );
    }

    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 4)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          return Expanded(
            child: _RadioOption(
              label: options[index],
              isSelected: selected == index,
              onTap: () => onChanged(index),
              isDark: isDark,
              isInContainer: true,
            ),
          );
        }),
      ),
    );
  }
}

// Radio Option Widget
class _RadioOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final bool isInContainer;
  final bool isSmall;

  const _RadioOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.isInContainer = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isInContainer) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: Responsive.fontSize(context, 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1A2C16) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isSmall
            ? Responsive.fontSize(context, 40)
            : Responsive.fontSize(context, 48),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF37EC13) : Colors.transparent,
          borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF37EC13).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmall
                ? Responsive.fontSize(context, 12)
                : Responsive.fontSize(context, 14),
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}