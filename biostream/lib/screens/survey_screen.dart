import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import '../services/lifestyle_service.dart';
import 'result_screen.dart';

class SurveyScreen extends StatefulWidget {
  final String? originalImageUrl;

  const SurveyScreen({
    super.key,
    this.originalImageUrl,
  });

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final PageController _pageController = PageController();
  final LifestyleService _lifestyleService = LifestyleService();
  int _currentPage = 0;
  bool _showSwipeHint = true;

  // A. 주요 목표
  List<String> _outcomes = [];

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
  List<String> _skinConcerns = [];
  double? _skinSatisfaction = 5.0; // 피부 만족도 기본값

  // 목표 연도
  double _targetYears = 30.0;

  // 참고할 상황 (선택, 마지막 입력, DB 저장 안 함)
  final TextEditingController _situationTextController = TextEditingController();
  static const int _situationTextMaxLength = 200;

  final int _totalPages = 9; // 8개 섹션 + 1개 요약

  @override
  void dispose() {
    _pageController.dispose();
    _smokingAmountController.dispose();
    _situationTextController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildLifestyleData() {
    return {
      "outcomes": _outcomes,
      "sleep_hours_weekday": _sleepHoursWeekday,
      "sleep_hours_weekend": _sleepHoursWeekend,
      "sleep_quality_score": _sleepQualityScore,
      "uv_exposure_10to16": _uvExposure10to16,
      "sunscreen_frequency": _sunscreenFrequency,
      "sunscreen_reapply": _sunscreenReapply,
      "outdoor_sports_uv": _outdoorSportsUv,
      "drinking_days_per_week": _drinkingDaysPerWeek,
      "drinking_amount_per_session": _drinkingAmountPerSession,
      "smoking_status": _smokingStatus,
      "smoking_amount_per_day":
          _smokingAmountUnit != null && _smokingAmountController.text.isNotEmpty
              ? "${_smokingAmountController.text}${_smokingAmountUnit}"
              : null,
      "stress_score": _stressScore,
      "caffeine_intake": _caffeineIntake,
      "caffeine_timing": _caffeineTiming,
      "aerobic_weekly": _aerobicWeekly,
      "resistance_weekly": _resistanceWeekly,
      "height": _height,
      "weight": _weight,
      "skin_type": _skinType,
      "skin_concerns": _skinConcerns,
      "skin_satisfaction": _skinSatisfaction,
      "target_years": _targetYears.toInt(),
      if (widget.originalImageUrl != null)
        "original_image_url": widget.originalImageUrl,
    };
  }

  Future<void> _submitSurvey() async {
    final lifestyleData = _buildLifestyleData();

    debugPrint('[SurveyScreen] 설문 데이터 제출 시작');
    final result = await _lifestyleService.saveLifestyleProfile(lifestyleData);

    if (result['success'] == true && mounted) {
      final situationText = _situationTextController.text.trim();
      final situationForReport = situationText.isNotEmpty ? situationText : null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ResultScreen(situationText: situationForReport),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '저장에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            _buildProgressBar(isDark),
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
                      _buildOutcomesPage(isDark),
                      _buildSleepPage(isDark),
                      _buildUVPage(isDark),
                      _buildAlcoholSmokingPage(isDark),
                      _buildStressPage(isDark),
                      _buildActivityPage(isDark),
                      _buildSkinPage(isDark),
                      _buildTargetYearsPage(isDark),
                      _buildSummaryPage(isDark),
                    ],
                  ),
                  // Swipe Hint
                  if (_showSwipeHint && _currentPage == 0)
                    _buildSwipeHint(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    final isSummaryPage = _currentPage == _totalPages - 1;

    return AnimatedOpacity(
      opacity: isSummaryPage ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: isSummaryPage ? 0 : null,
        child: Container(
          padding: EdgeInsets.all(Responsive.padding(context, 16)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_currentPage + 1} / $_totalPages',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF37EC13),
                    ),
                  ),
                  if (_currentPage < _totalPages - 1)
                    TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          _totalPages - 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Text(
                        '요약으로',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          color: const Color(0xFF37EC13),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: Responsive.padding(context, 8)),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: (_currentPage + 1) / _totalPages,
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.1)
                        : const Color(0xFFD3E7CF),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF37EC13)),
                    minHeight: Responsive.fontSize(context, 4),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeHint(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showSwipeHint = false;
        });
      },
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            margin: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 32)),
            padding: EdgeInsets.all(Responsive.padding(context, 24)),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2C16) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swipe,
                  size: Responsive.iconSize(context, 48),
                  color: const Color(0xFF37EC13),
                ),
                SizedBox(height: Responsive.padding(context, 16)),
                Text(
                  '좌우로 넘겨서\n설문을 완료해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: Responsive.padding(context, 8)),
                Text(
                  '터치하여 닫기',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // A. 주요 목표 페이지
  Widget _buildOutcomesPage(bool isDark) {
    final options = [
      {'value': 'wrinkle', 'label': '주름'},
      {'value': 'elasticity', 'label': '탄력'},
      {'value': 'pigmentation', 'label': '색소'},
      {'value': 'hydration', 'label': '수분'},
      {'value': 'hydration_barrier', 'label': '장벽'},
      {'value': 'acne', 'label': '여드름'},
      {'value': 'redness', 'label': '홍조'},
      {'value': 'general_aging', 'label': '전체 노화'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '주요 목표',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 8)),
              Text(
                '관심 있는 피부 고민을 선택해주세요 (복수 선택 가능)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: options.map((option) {
                  final isSelected = _outcomes.contains(option['value']);
                  return _buildChip(
                    label: option['label']!,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _outcomes.remove(option['value']);
                        } else {
                          _outcomes.add(option['value']!);
                        }
                      });
                    },
                    isDark: isDark,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // B. Sleep & Rhythm 페이지
  Widget _buildSleepPage(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '수면 패턴',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _buildSliderField(
                label: '평균 수면시간 (평일)',
                value: _sleepHoursWeekday!,
                min: 3.0,
                max: 10.0,
                divisions: 7, // 자연수 단위 (3, 4, 5, 6, 7, 8, 9, 10)
                suffix: '시간',
                isInteger: true,
                onChanged: (value) =>
                    setState(() => _sleepHoursWeekday = value),
                isDark: isDark,
              ),
              SizedBox(height: Responsive.padding(context, 24)),
              _buildSliderField(
                label: '평균 수면시간 (주말)',
                value: _sleepHoursWeekend!,
                min: 3.0,
                max: 10.0,
                divisions: 7, // 자연수 단위
                suffix: '시간',
                isInteger: true,
                onChanged: (value) =>
                    setState(() => _sleepHoursWeekend = value),
                isDark: isDark,
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _buildSliderField(
                label: '수면의 질 (주관)',
                value: _sleepQualityScore!,
                min: 0.0,
                max: 10.0,
                divisions: 10, // 자연수 단위 (0~10)
                suffix: '점',
                isInteger: true,
                onChanged: (value) =>
                    setState(() => _sleepQualityScore = value),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // C. UV / Photoaging 페이지
  Widget _buildUVPage(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '자외선 노출',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '야외 노출 (10~16시)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '<30m', 'label': '30분 미만'},
                  {'value': '30~60', 'label': '30분~1시간'},
                  {'value': '1~2h', 'label': '1~2시간'},
                  {'value': '>2h', 'label': '2시간 이상'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _uvExposure10to16 == option['value'],
                    onTap: () =>
                        setState(() => _uvExposure10to16 = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '선크림 사용 빈도',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'never', 'label': '안함'},
                  {'value': 'sometimes', 'label': '가끔'},
                  {'value': 'most_days', 'label': '대부분'},
                  {'value': 'daily_with_reapply', 'label': '매일 (재도포 포함)'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _sunscreenFrequency == option['value'],
                    onTap: () =>
                        setState(() => _sunscreenFrequency = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '재도포 (2~3시간 간격)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'never', 'label': '안함'},
                  {'value': 'rarely', 'label': '드물게'},
                  {'value': 'sometimes', 'label': '가끔'},
                  {'value': 'often', 'label': '자주'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _sunscreenReapply == option['value'],
                    onTap: () =>
                        setState(() => _sunscreenReapply = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '야외스포츠 (강한 UV)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'none', 'label': '안함'},
                  {'value': 'monthly', 'label': '월 1회'},
                  {'value': 'weekly', 'label': '주 1회 이상'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _outdoorSportsUv == option['value'],
                    onTap: () =>
                        setState(() => _outdoorSportsUv = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // D. Alcohol & Smoking 페이지
  Widget _buildAlcoholSmokingPage(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '음주 및 흡연',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '주당 음주일수',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0일'},
                  {'value': '1', 'label': '1일'},
                  {'value': '2-3', 'label': '2-3일'},
                  {'value': '4-5', 'label': '4-5일'},
                  {'value': '6-7', 'label': '6-7일'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _drinkingDaysPerWeek == option['value'],
                    onTap: () =>
                        setState(() => _drinkingDaysPerWeek = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '1회 음주량',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 40)),
                child: _buildTextField(
                  label: '',
                  value: _drinkingAmountPerSession,
                  placeholder: '예: 소주 5잔, 맥주 2병',
                  onChanged: (value) =>
                      setState(() => _drinkingAmountPerSession = value),
                  isDark: isDark,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '흡연/니코틴',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'never', 'label': '안함'},
                  {'value': 'former', 'label': '과거 흡연'},
                  {'value': 'current', 'label': '현재 흡연'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _smokingStatus == option['value'],
                    onTap: () {
                      setState(() {
                        _smokingStatus = option['value'];
                        if (option['value'] != 'current') {
                          _smokingAmountUnit = null;
                          _smokingAmountController.clear();
                        }
                      });
                    },
                    isDark: isDark,
                  );
                }).toList(),
              ),
              if (_smokingStatus == 'current') ...[
                SizedBox(height: Responsive.padding(context, 32)),
                Text(
                  '흡연량 단위',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                SizedBox(height: Responsive.padding(context, 16)),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Responsive.padding(context, 12),
                  runSpacing: Responsive.padding(context, 12),
                  children: [
                    {'value': '갑', 'label': '갑'},
                    {'value': '개비', 'label': '개비'},
                  ].map((option) {
                    return _buildChoiceButton(
                      label: option['label']!,
                      isSelected: _smokingAmountUnit == option['value'],
                      onTap: () =>
                          setState(() => _smokingAmountUnit = option['value']),
                      isDark: isDark,
                    );
                  }).toList(),
                ),
                if (_smokingAmountUnit != null) ...[
                  SizedBox(height: Responsive.padding(context, 32)),
                  Text(
                    '하루 흡연량',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: Responsive.padding(context, 16)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: Responsive.padding(context, 40)),
                    child: _buildNumberTextField(
                      label: '',
                      controller: _smokingAmountController,
                      placeholder: '0',
                      suffix: _smokingAmountUnit!,
                      isDark: isDark,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // E. Stress & Recovery 페이지
  Widget _buildStressPage(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '스트레스 및 회복',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _buildSliderField(
                label: '스트레스 (지난 2주)',
                value: _stressScore!,
                min: 0.0,
                max: 10.0,
                divisions: 10, // 자연수 단위 (0~10)
                suffix: '점',
                isInteger: true,
                onChanged: (value) => setState(() => _stressScore = value),
                isDark: isDark,
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '카페인 섭취량',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0잔'},
                  {'value': '1', 'label': '1잔'},
                  {'value': '2', 'label': '2잔'},
                  {'value': '3+', 'label': '3잔 이상'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _caffeineIntake == option['value'],
                    onTap: () =>
                        setState(() => _caffeineIntake = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '카페인 섭취 시간대',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': 'before_noon', 'label': '오전'},
                  {'value': 'afternoon', 'label': '오후'},
                  {'value': 'evening', 'label': '저녁'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _caffeineTiming == option['value'],
                    onTap: () =>
                        setState(() => _caffeineTiming = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // F. Activity & Metabolic 페이지
  Widget _buildActivityPage(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '활동 및 대사',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '유산소 (주당)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0회'},
                  {'value': '1-2', 'label': '1-2회'},
                  {'value': '3-4', 'label': '3-4회'},
                  {'value': '5+', 'label': '5회 이상'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _aerobicWeekly == option['value'],
                    onTap: () =>
                        setState(() => _aerobicWeekly = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '근력 (주당)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: [
                  {'value': '0', 'label': '0회'},
                  {'value': '1', 'label': '1회'},
                  {'value': '2', 'label': '2회'},
                  {'value': '3+', 'label': '3회 이상'},
                ].map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _resistanceWeekly == option['value'],
                    onTap: () =>
                        setState(() => _resistanceWeekly = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Row(
                children: [
                  Expanded(
                    child: _buildIntegerTextField(
                      label: '키 (cm)',
                      value: _height?.toInt(),
                      placeholder: '170',
                      onChanged: (value) => setState(() =>
                          _height = value != null ? value.toDouble() : null),
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(width: Responsive.padding(context, 16)),
                  Expanded(
                    child: _buildIntegerTextField(
                      label: '몸무게 (kg)',
                      value: _weight?.toInt(),
                      placeholder: '60',
                      onChanged: (value) => setState(() =>
                          _weight = value != null ? value.toDouble() : null),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Skin 상태 페이지
  Widget _buildSkinPage(bool isDark) {
    final skinTypes = [
      {'value': 'dry', 'label': '건성'},
      {'value': 'oily', 'label': '지성'},
      {'value': 'combination', 'label': '복합성'},
      {'value': 'sensitive', 'label': '민감성'},
    ];

    final skinConcernOptions = [
      {'value': 'wrinkle', 'label': '주름'},
      {'value': 'pigmentation', 'label': '색소'},
      {'value': 'elasticity', 'label': '탄력'},
      {'value': 'dryness', 'label': '건조'},
      {'value': 'redness', 'label': '홍조'},
      {'value': 'acne', 'label': '트러블'},
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '피부 상태',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Text(
                '피부 타입',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 16)),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: skinTypes.map((option) {
                  return _buildChoiceButton(
                    label: option['label']!,
                    isSelected: _skinType == option['value'],
                    onTap: () => setState(() => _skinType = option['value']),
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 24)),
              Text(
                '주요 피부 고민 (복수 선택 가능)',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 12)),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Responsive.padding(context, 12),
                runSpacing: Responsive.padding(context, 12),
                children: skinConcernOptions.map((option) {
                  final isSelected = _skinConcerns.contains(option['value']);
                  return _buildChip(
                    label: option['label']!,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _skinConcerns.remove(option['value']);
                        } else {
                          _skinConcerns.add(option['value']!);
                        }
                      });
                    },
                    isDark: isDark,
                  );
                }).toList(),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              _buildSliderField(
                label: '현재 피부상태 만족도',
                value: _skinSatisfaction!,
                min: 0.0,
                max: 10.0,
                divisions: 10, // 자연수 단위 (0~10)
                suffix: '점',
                isInteger: true,
                onChanged: (value) => setState(() => _skinSatisfaction = value),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 목표 연도 페이지
  Widget _buildTargetYearsPage(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '목표 미래 나이',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 8)),
              Text(
                'AI 모델이 예측할 미래 시점을 선택하세요.',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              Container(
                padding: EdgeInsets.all(Responsive.padding(context, 24)),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2C16) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '+${_targetYears.toInt()}년 후',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 48),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF37EC13),
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 24)),
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
                      ),
                      child: Slider(
                        value: _targetYears,
                        min: 10,
                        max: 50,
                        divisions: 4,
                        onChanged: (value) =>
                            setState(() => _targetYears = value),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('+10년',
                            style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600])),
                        Text('+20년',
                            style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600])),
                        Text('+30년',
                            style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF37EC13))),
                        Text('+40년',
                            style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600])),
                        Text('+50년',
                            style: TextStyle(
                                fontSize: Responsive.fontSize(context, 12),
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 요약 페이지
  Widget _buildSummaryPage(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참고할 상황 (선택)',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            '리포트에 반영해 주었으면 하는 상황이나 특성을 간단히 적어주세요. 비워두어도 됩니다.',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
          SizedBox(height: Responsive.padding(context, 12)),
          TextField(
            controller: _situationTextController,
            maxLength: _situationTextMaxLength,
            maxLines: 3,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: '예: 야근이 많아 새벽에 자요. 3개월 뒤 중요한 일이 있어요.',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2C16) : Colors.white,
              contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
            ),
          ),
          SizedBox(height: Responsive.padding(context, 24)),
          Text(
            '입력 요약',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 28),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: Responsive.padding(context, 24)),
          _buildSummaryCard(
            title: '주요 목표',
            content: _outcomes.isEmpty
                ? '미입력'
                : _outcomes.map((o) {
                    final labels = {
                      'wrinkle': '주름',
                      'elasticity': '탄력',
                      'pigmentation': '색소',
                      'hydration': '수분',
                      'hydration_barrier': '장벽',
                      'acne': '여드름',
                      'redness': '홍조',
                      'general_aging': '전체 노화',
                    };
                    return labels[o] ?? o;
                  }).join(', '),
            isDark: isDark,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _buildSummaryCard(
            title: '수면 패턴',
            content:
                '평일: ${_sleepHoursWeekday!.toInt()}h, 주말: ${_sleepHoursWeekend!.toInt()}h, 질: ${_sleepQualityScore!.toInt()}점',
            isDark: isDark,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _buildSummaryCard(
            title: '자외선 노출',
            content: _getUVExposureSummary(),
            isDark: isDark,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _buildSummaryCard(
            title: '음주 및 흡연',
            content: _getDrinkingSmokingSummary(),
            isDark: isDark,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _buildSummaryCard(
            title: '스트레스 및 회복',
            content:
                '스트레스: ${_stressScore!.toInt()}점, 카페인: ${_caffeineIntake ?? '미입력'}${_caffeineTiming != null ? ' (${_getCaffeineTimingLabel(_caffeineTiming)})' : ''}',
            isDark: isDark,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _buildSummaryCard(
            title: '활동 및 대사',
            content:
                '유산소: ${_getAerobicLabel(_aerobicWeekly)}, 근력: ${_getResistanceLabel(_resistanceWeekly)}, 키/몸무게: ${_height != null ? "${_height!.toInt()}cm" : "미입력"} / ${_weight != null ? "${_weight!.toInt()}kg" : "미입력"}',
            isDark: isDark,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _buildSummaryCard(
            title: '피부 상태',
            content:
                '타입: ${_getSkinTypeLabel(_skinType)}, 고민: ${_skinConcerns.isEmpty ? '없음' : _skinConcerns.map((c) => _getSkinConcernLabel(c)).join(', ')}, 만족도: ${_skinSatisfaction!.toInt()}점',
            isDark: isDark,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _buildSummaryCard(
            title: '목표 연도',
            content: '+${_targetYears.toInt()}년 후',
            isDark: isDark,
          ),
          SizedBox(height: Responsive.padding(context, 32)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitSurvey,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37EC13),
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.padding(context, 18),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '제출하기',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      {required String title, required String content, required bool isDark}) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2C16) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF37EC13),
            ),
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            content,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
      {required String label,
      required bool isSelected,
      required VoidCallback onTap,
      required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 24),
          vertical: Responsive.padding(context, 14),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF37EC13)
              : (isDark ? const Color(0xFF1A2C16) : Colors.white),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark ? Colors.white.withOpacity(0.15) : Colors.grey[300]!),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
          ),
        ),
      ),
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
    final displayValue = isInteger ? value.toInt() : value;
    final displayText = isInteger
        ? '${displayValue}$suffix'
        : '${displayValue.toStringAsFixed(1)}$suffix';

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: Responsive.padding(context, 40)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            displayText,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 24),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF37EC13),
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
                enabledThumbRadius: Responsive.fontSize(context, 10),
              ),
            ),
            child: Slider(
              value: isInteger ? value.roundToDouble() : value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (newValue) {
                if (isInteger) {
                  onChanged(newValue.roundToDouble());
                } else {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 24),
          vertical: Responsive.padding(context, 14),
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF37EC13) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF37EC13)
                : (isDark ? Colors.white.withOpacity(0.15) : Colors.grey[300]!),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
          ),
        ),
      ),
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
    return _TextFieldBuilder(
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
    return _IntegerTextFieldBuilder(
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
    if (label.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
                contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
              ),
            ),
          ),
          SizedBox(width: Responsive.padding(context, 8)),
          Text(
            suffix,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF132210)
                      : const Color(0xFFF6F8F6),
                  contentPadding:
                      EdgeInsets.all(Responsive.padding(context, 16)),
                ),
              ),
            ),
            SizedBox(width: Responsive.padding(context, 8)),
            Text(
              suffix,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getUVExposureSummary() {
    final parts = <String>[];
    if (_uvExposure10to16 != null)
      parts.add('야외노출: ${_getUVExposureLabel(_uvExposure10to16)}');
    if (_sunscreenFrequency != null)
      parts.add('선크림: ${_getSunscreenFreqLabel(_sunscreenFrequency)}');
    if (_sunscreenReapply != null)
      parts.add('재도포: ${_getSunscreenReapplyLabel(_sunscreenReapply)}');
    if (_outdoorSportsUv != null)
      parts.add('야외스포츠: ${_getOutdoorSportsLabel(_outdoorSportsUv)}');
    return parts.isEmpty ? '미입력' : parts.join(', ');
  }

  String _getDrinkingSmokingSummary() {
    final parts = <String>[];
    if (_drinkingDaysPerWeek != null)
      parts.add('음주: ${_getDrinkingDaysLabel(_drinkingDaysPerWeek)}');
    if (_drinkingAmountPerSession != null &&
        _drinkingAmountPerSession!.isNotEmpty)
      parts.add('1회량: $_drinkingAmountPerSession');
    if (_smokingStatus != null) {
      final smokingLabel = _smokingStatus == 'never'
          ? '안함'
          : (_smokingStatus == 'former' ? '과거 흡연' : '현재 흡연');
      parts.add('흡연: $smokingLabel');
      if (_smokingStatus == 'current' &&
          _smokingAmountUnit != null &&
          _smokingAmountController.text.isNotEmpty) {
        parts.add('${_smokingAmountController.text}${_smokingAmountUnit}');
      }
    }
    return parts.isEmpty ? '미입력' : parts.join(', ');
  }

  String _getUVExposureLabel(String? value) {
    const map = {
      '<30m': '30분 미만',
      '30~60': '30분~1시간',
      '1~2h': '1~2시간',
      '>2h': '2시간 이상'
    };
    return map[value] ?? value ?? '';
  }

  String _getSunscreenFreqLabel(String? value) {
    const map = {
      'never': '안함',
      'sometimes': '가끔',
      'most_days': '대부분',
      'daily_with_reapply': '매일(재도포)'
    };
    return map[value] ?? value ?? '';
  }

  String _getSunscreenReapplyLabel(String? value) {
    const map = {
      'never': '안함',
      'rarely': '드물게',
      'sometimes': '가끔',
      'often': '자주'
    };
    return map[value] ?? value ?? '';
  }

  String _getOutdoorSportsLabel(String? value) {
    const map = {'none': '안함', 'monthly': '월 1회', 'weekly': '주 1회 이상'};
    return map[value] ?? value ?? '';
  }

  String _getDrinkingDaysLabel(String? value) {
    const map = {
      '0': '0일',
      '1': '1일',
      '2-3': '2-3일',
      '4-5': '4-5일',
      '6-7': '6-7일'
    };
    return map[value] ?? value ?? '';
  }

  String _getCaffeineTimingLabel(String? value) {
    const map = {'before_noon': '오전', 'afternoon': '오후', 'evening': '저녁'};
    return map[value] ?? '';
  }

  String _getAerobicLabel(String? value) {
    const map = {'0': '0회', '1-2': '1-2회', '3-4': '3-4회', '5+': '5회 이상'};
    return map[value] ?? value ?? '미입력';
  }

  String _getResistanceLabel(String? value) {
    const map = {'0': '0회', '1': '1회', '2': '2회', '3+': '3회 이상'};
    return map[value] ?? value ?? '미입력';
  }

  String _getSkinTypeLabel(String? value) {
    const map = {
      'dry': '건성',
      'oily': '지성',
      'combination': '복합성',
      'sensitive': '민감성'
    };
    return map[value] ?? value ?? '미입력';
  }

  String _getSkinConcernLabel(String value) {
    const map = {
      'wrinkle': '주름',
      'pigmentation': '색소',
      'elasticity': '탄력',
      'dryness': '건조',
      'redness': '홍조',
      'acne': '트러블'
    };
    return map[value] ?? value;
  }
}

// Integer TextField를 위한 별도 StatefulWidget
class _IntegerTextFieldBuilder extends StatefulWidget {
  final String label;
  final int? value;
  final String placeholder;
  final ValueChanged<int?> onChanged;
  final bool isDark;

  const _IntegerTextFieldBuilder({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<_IntegerTextFieldBuilder> createState() =>
      _IntegerTextFieldBuilderState();
}

class _IntegerTextFieldBuilderState extends State<_IntegerTextFieldBuilder> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value?.toString() ?? '');
    _controller.addListener(() {
      final text = _controller.text;
      if (text.isEmpty) {
        widget.onChanged(null);
      } else {
        final value = int.tryParse(text);
        widget.onChanged(value);
      }
    });
  }

  @override
  void didUpdateWidget(_IntegerTextFieldBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        widget.value?.toString() != _controller.text) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.label.isEmpty) {
      return TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 16),
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyle(
            color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor:
              widget.isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
          contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: widget.isDark
                ? const Color(0xFF132210)
                : const Color(0xFFF6F8F6),
            contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
          ),
        ),
      ],
    );
  }
}

// TextField를 위한 별도 StatefulWidget
class _TextFieldBuilder extends StatefulWidget {
  final String label;
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;
  final bool isDark;
  final TextInputType keyboardType;

  const _TextFieldBuilder({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onChanged,
    required this.isDark,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<_TextFieldBuilder> createState() => _TextFieldBuilderState();
}

class _TextFieldBuilderState extends State<_TextFieldBuilder> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    _controller.addListener(() {
      widget.onChanged(_controller.text.isEmpty ? null : _controller.text);
    });
  }

  @override
  void didUpdateWidget(_TextFieldBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.label.isEmpty) {
      return TextField(
        controller: _controller,
        keyboardType: widget.keyboardType,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: Responsive.fontSize(context, 16),
          color: widget.isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyle(
            color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor:
              widget.isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
          contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        TextField(
          controller: _controller,
          keyboardType: widget.keyboardType,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 16),
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            hintStyle: TextStyle(
              color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: widget.isDark
                ? const Color(0xFF132210)
                : const Color(0xFFF6F8F6),
            contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
          ),
        ),
      ],
    );
  }
}
