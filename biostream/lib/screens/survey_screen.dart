import 'package:flutter/material.dart';
import '../services/lifestyle_service.dart';
import '../services/profile_service.dart';
import '../services/exercise_auto_fill_service.dart';
import '../services/sleep_auto_fill_service.dart';
import 'result/result_screen.dart';
import 'survey/survey_controller.dart';
import '../widgets/survey/common/survey_form_fields.dart';
import '../widgets/survey/pages/survey_activity_page.dart';
import '../widgets/survey/pages/survey_alcohol_smoking_page.dart';
import '../widgets/survey/pages/survey_outcomes_page.dart';
import '../widgets/survey/pages/survey_skin_page.dart';
import '../widgets/survey/pages/survey_sleep_page.dart';
import '../widgets/survey/pages/survey_stress_page.dart';
import '../widgets/survey/pages/survey_summary_page.dart';
import '../widgets/survey/pages/survey_uv_page.dart';
import '../widgets/survey/survey_progress_header.dart';
import '../utils/app_snackbar.dart';
import '../widgets/survey/survey_swipe_hint.dart';
import '../widgets/survey/survey_ai_generating_dialog.dart';

class SurveyScreen extends StatefulWidget {
  final String? originalImageUrl;
  final int? lifestyleId;
  final bool showHomeButtonOnFirstPage;

  const SurveyScreen({
    super.key,
    this.originalImageUrl,
    this.lifestyleId,
    this.showHomeButtonOnFirstPage = false,
  });

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final PageController _pageController = PageController();
  final LifestyleService _lifestyleService = LifestyleService();
  final ProfileService _profileService = ProfileService();
  late final SurveyController _surveyController;
  int _currentPage = 0;
  bool _showSwipeHint = true;
  bool _heightEditedByUser = false;
  bool _weightEditedByUser = false;
  bool _isSubmittingSurvey = false;

  // A. 주요 목표
  final List<String> _outcomes = [];

  // B. Sleep & Rhythm (기본값 설정 - 슬라이더 표시값이 자동으로 저장됨)
  double? _sleepHoursWeekday = 7.0; // 평균 수면시간 평일 기본값
  double? _sleepHoursWeekend = 7.0; // 평균 수면시간 주말 기본값
  double? _sleepQualityScore = 5.0; // 수면의 질 기본값

  // C. UV / Photoaging
  String? _uvExposure10to16;
  String? _sunscreenFrequency;

  // D. Alcohol & Smoking
  String? _drinkingDaysPerWeek;
  String? _smokingStatus;
  String? _smokingDaysPerWeek;

  // E. Stress & Recovery (기본값 설정)
  double? _stressScore = 5.0; // 스트레스 점수 기본값

  // F. Activity & Metabolic
  String? _aerobicWeekly;
  String? _resistanceWeekly;

  /// 회원가입/프로필에서 저장한 흡연 여부. 'never'면 흡연 설문 생략
  String? _userSmokingStatus;
  double? _height;
  double? _weight;

  // Skin 상태 (기본값 설정)
  String? _skinType;
  double? _skinSatisfaction = 5.0; // 피부 만족도 기본값

  // 자동 채우기 출처 힌트 (수정 가능, 문구 표시용)
  String? _sleepPrefillHint;
  String? _exercisePrefillHint;

  // 참고할 상황 (선택, 마지막 입력, DB 저장 안 함)
  final TextEditingController _situationTextController =
      TextEditingController();
  static const int _situationTextMaxLength = 200;

  final int _totalPages = 8; // 7개 섹션 + 1개 요약

  @override
  void initState() {
    super.initState();
    _surveyController = SurveyController(lifestyleService: _lifestyleService);
    _initSurveyPrefill();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _situationTextController.dispose();
    super.dispose();
  }

  /// 흡연 여부 로드 → 최근 7일 스냅샷 → 키·몸무게(설문·프로필 출처) → 운동·수면은 스냅샷 빈칸만 기기 건강 등으로 보완
  Future<void> _initSurveyPrefill() async {
    await _loadUserSmokingStatus();
    if (!mounted) return;
    await Future.wait([
      _prefillFromLast7DaySnapshots(),
      _prefillBodyMetrics(),
    ]);
    if (!mounted) return;
    await _prefillExerciseData();
    if (!mounted) return;
    await _prefillSleepData();
  }

  Future<void> _prefillBodyMetrics() async {
    double? savedHeight;
    double? savedWeight;

    final n = DateTime.now();
    final todayDateStr =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final todayLs = await _lifestyleService.getTodayLifestyle(forCalendarDate: todayDateStr);
    if (todayLs['success'] == true && todayLs['data'] is Map<String, dynamic>) {
      final d = todayLs['data'] as Map<String, dynamic>;
      savedHeight = _extractMetricNumber(d['heightCm']);
      savedWeight = _extractMetricNumber(d['weightKg']);
    }

    if ((savedHeight == null || savedHeight <= 0) ||
        (savedWeight == null || savedWeight <= 0)) {
      final result = await _lifestyleService.getLifestyleData();
      if (!mounted || result['success'] != true) {
        return;
      }

      final data = result['data'];
      if (data is! Map<String, dynamic>) {
        return;
      }

      final bodystate = data['bodystate'];
      if (bodystate is! Map<String, dynamic>) {
        return;
      }

      savedHeight ??= _extractMetricNumber(bodystate['height_cm']);
      savedWeight ??= _extractMetricNumber(bodystate['weight_kg']);
    }

    if (!mounted) return;

    setState(() {
      if (!_heightEditedByUser && savedHeight != null && savedHeight > 0) {
        _height = savedHeight;
      }
      if (!_weightEditedByUser && savedWeight != null && savedWeight > 0) {
        _weight = savedWeight;
      }
    });
  }

  /// 최근 7일 일별 스냅샷 집계(스냅샷과 동일한 보간: 기록된 날만으로 주간 추정)
  Future<void> _prefillFromLast7DaySnapshots() async {
    final hist = await _lifestyleService.getDailyLifestyleHistory(days: 7);
    if (!mounted || hist['success'] != true || hist['data'] is! Map<String, dynamic>) {
      return;
    }
    final data = hist['data'] as Map<String, dynamic>;
    final rawItems = data['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      return;
    }

    final items = rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

    String? uvMode;
    final uvVals = <String>[];
    for (final row in items) {
      final u = row['uvOutdoor10to16']?.toString().trim();
      if (u != null && u.isNotEmpty) uvVals.add(u);
    }
    if (uvVals.isNotEmpty) {
      uvMode = _mostFrequent(uvVals);
    }

    String? sunscreenBucket;
    final sunKnown = <bool>[];
    for (final row in items) {
      if (!row.containsKey('sunscreenApplied')) continue;
      final v = row['sunscreenApplied'];
      if (v == null) continue;
      sunKnown.add(v == true || v == 'true');
    }
    if (sunKnown.isNotEmpty) {
      final applied = sunKnown.where((x) => x).length;
      sunscreenBucket = _weeklyBucketFromEstimatedDays(
        (7 * applied / sunKnown.length).round(),
      );
    }

    String? drinkingBucket;
    final drinkKnown = <bool>[];
    for (final row in items) {
      final d = row['drinkingDaysPerWeek']?.toString().trim();
      if (d == null || d.isEmpty) continue;
      if (d != '0' && d != '1') {
        drinkKnown.clear();
        break;
      }
      drinkKnown.add(d == '1');
    }
    if (drinkKnown.isNotEmpty) {
      final drank = drinkKnown.where((x) => x).length;
      drinkingBucket = _weeklyBucketFromEstimatedDays(
        (7 * drank / drinkKnown.length).round(),
      );
    }

    String? smokingDaysBucket;
    if (_userSmokingStatus != 'never') {
      final smokeKnown = <bool>[];
      for (final row in items) {
        final s = row['smokingStatus']?.toString().trim().toLowerCase();
        if (s == null || s.isEmpty) continue;
        if (s != 'current' && s != 'never') {
          smokeKnown.clear();
          break;
        }
        smokeKnown.add(s == 'current');
      }
      if (smokeKnown.isNotEmpty) {
        final smoked = smokeKnown.where((x) => x).length;
        smokingDaysBucket = _weeklyBucketFromEstimatedDays(
          (7 * smoked / smokeKnown.length).round(),
        );
      }
    }

    double? stressAvg;
    final stressVals = <double>[];
    for (final row in items) {
      final s = _extractMetricNumber(row['stressScore']);
      if (s != null) stressVals.add(s);
    }
    if (stressVals.isNotEmpty) {
      stressAvg = stressVals.reduce((a, b) => a + b) / stressVals.length;
    }

    final wdMins = <int>[];
    final weMins = <int>[];
    for (final row in items) {
      final min = _parsePositiveInt(row['sleepMinutes']);
      if (min == null) continue;
      final dt = _parseSnapshotDate(row['date']?.toString());
      if (dt == null) continue;
      if (dt.weekday <= DateTime.friday) {
        wdMins.add(min);
      } else {
        weMins.add(min);
      }
    }
    double? wdH;
    double? weH;
    if (wdMins.isNotEmpty) {
      wdH = (wdMins.reduce((a, b) => a + b) / wdMins.length / 60.0);
      wdH = (wdH * 10).round() / 10.0;
    }
    if (weMins.isNotEmpty) {
      weH = (weMins.reduce((a, b) => a + b) / weMins.length / 60.0);
      weH = (weH * 10).round() / 10.0;
    }
    if (wdH != null && weH == null) weH = wdH;
    if (weH != null && wdH == null) wdH = weH;

    double? sleepQAvg;
    final sqVals = <double>[];
    for (final row in items) {
      final s = _extractMetricNumber(row['sleepQualityScore']);
      if (s != null) sqVals.add(s);
    }
    if (sqVals.isNotEmpty) {
      sleepQAvg = sqVals.reduce((a, b) => a + b) / sqVals.length;
      sleepQAvg = (sleepQAvg * 10).round() / 10.0;
    }

    int aerSum = 0;
    int resSum = 0;
    var aerAny = false;
    var resAny = false;
    for (final row in items) {
      final a = _parsePositiveInt(row['aerobicSessions30min']);
      final r = _parsePositiveInt(row['resistanceSessions30min']);
      if (a != null) {
        aerSum += a;
        aerAny = true;
      }
      if (r != null) {
        resSum += r;
        resAny = true;
      }
    }
    String? aerobicFromSnap;
    String? resistanceFromSnap;
    if (aerAny) {
      aerobicFromSnap = _exerciseMinutesToSurveyAerobic(aerSum);
    }
    if (resAny) {
      resistanceFromSnap = _mapResistanceWeekly(resSum);
    }

    const snapHint = '최근 7일 생활 기록에서 가져왔습니다.';

    if (!mounted) return;
    setState(() {
      if (_uvExposure10to16 == null && uvMode != null) {
        _uvExposure10to16 = uvMode;
      }
      if (_sunscreenFrequency == null && sunscreenBucket != null) {
        _sunscreenFrequency = sunscreenBucket;
      }
      if (_drinkingDaysPerWeek == null && drinkingBucket != null) {
        _drinkingDaysPerWeek = drinkingBucket;
      }
      if (_userSmokingStatus != 'never' &&
          _smokingStatus == 'current' &&
          _smokingDaysPerWeek == null &&
          smokingDaysBucket != null) {
        _smokingDaysPerWeek = smokingDaysBucket;
      }
      if (stressAvg != null) {
        _stressScore = stressAvg.clamp(0.0, 10.0);
      }
      if (wdH != null &&
          weH != null &&
          wdH >= 3 &&
          wdH <= 10 &&
          weH >= 3 &&
          weH <= 10) {
        _sleepHoursWeekday = wdH;
        _sleepHoursWeekend = weH;
        _sleepPrefillHint = snapHint;
      }
      if (sleepQAvg != null) {
        _sleepQualityScore = sleepQAvg.clamp(0.0, 10.0);
        _sleepPrefillHint ??= snapHint;
      }
      if (_aerobicWeekly == null && aerobicFromSnap != null) {
        _aerobicWeekly = aerobicFromSnap;
        _exercisePrefillHint = snapHint;
      }
      if (_resistanceWeekly == null && resistanceFromSnap != null) {
        _resistanceWeekly = resistanceFromSnap;
        _exercisePrefillHint ??= snapHint;
      }
    });
  }

  String _weeklyBucketFromEstimatedDays(int est) {
    final n = est.clamp(0, 7);
    if (n <= 0) return '0';
    if (n == 1) return '1';
    if (n <= 3) return '2-3';
    if (n <= 5) return '4-5';
    return '6-7';
  }

  String _mostFrequent(List<String> values) {
    final counts = <String, int>{};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  DateTime? _parseSnapshotDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  int? _parsePositiveInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v > 0 ? v : null;
    final n = int.tryParse(v.toString());
    if (n == null || n <= 0) return null;
    return n;
  }

  String _mapResistanceWeekly(int totalSessions) {
    if (totalSessions <= 0) return '0';
    if (totalSessions == 1) return '1';
    if (totalSessions == 2) return '2';
    return '3+';
  }

  double? _extractMetricNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(value);
      if (match != null) {
        return double.tryParse(match.group(0) ?? '');
      }
    }
    return null;
  }

  /// 유산소·근력 운동 설문 자동 채우기.
  /// 1) 기기 Health Connect/HealthKit 최근 7일, 2) health_data(어제), 3) 저장된 lifestyle.
  Future<void> _prefillExerciseData() async {
    if (_aerobicWeekly != null && _resistanceWeekly != null) {
      return;
    }

    String? savedAerobic;
    String? savedResistance;
    String? hint;

    // 1) 기기 Health Connect/HealthKit 최근 7일
    final suggested = await ExerciseAutoFillService.fetchSuggestedValues();
    if (suggested != null) {
      savedAerobic = suggested.aerobicWeekly;
      savedResistance = suggested.resistanceWeekly;
      hint = '건강 데이터에서 가져왔습니다.';
    }

    // 2) health_data - 최근 7일 집계(우선) 또는 어제 데이터
    if (savedAerobic == null || savedResistance == null) {
      final recent = await _lifestyleService.getRecentHealthSummary(days: 7);
      if (recent['success'] == true && recent['data'] is Map<String, dynamic>) {
        final d = recent['data'] as Map<String, dynamic>;
        final totalMin = _extractMetricNumber(d['exerciseMinutes']);
        if (totalMin != null && totalMin > 0) {
          // 7일 총 분 → 30분당 1회로 환산
          final weeklySessions = (totalMin / 30).floor();
          savedAerobic ??= _exerciseMinutesToSurveyAerobic(weeklySessions);
          hint ??= '건강 데이터에서 가져왔습니다.';
        }
      }
      if (savedAerobic == null) {
        final yesterday = await _lifestyleService.getYesterdayHealthData();
        if (yesterday['success'] == true &&
            yesterday['data'] is Map<String, dynamic>) {
          final healthData = yesterday['data'] as Map<String, dynamic>;
          final exerciseMinutes = _extractMetricNumber(healthData['exerciseMinutes']);
          if (exerciseMinutes != null && exerciseMinutes >= 15) {
            savedAerobic ??= '1-2'; // 어제 15분+ 운동했으면 주 1~2회 추정
            hint ??= '건강 데이터에서 가져왔습니다.';
          }
        }
      }
    }

    // 3) 저장된 lifestyle
    if (savedAerobic == null || savedResistance == null) {
      final result = await _lifestyleService.getLifestyleData();
      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        final data = result['data'] as Map<String, dynamic>;
        final activity = data['lifestyle']?['activity'] ?? data['activity'];
        if (activity is Map<String, dynamic>) {
          savedAerobic ??= _extractSurveyString(activity['aerobic_weekly']);
          savedResistance ??= _extractSurveyString(activity['resistance_weekly']);
          hint ??= '이전 설문에서 저장된 정보입니다.';
        }
      }
    }

    if (!mounted) return;
    setState(() {
      if (_aerobicWeekly == null && savedAerobic != null) _aerobicWeekly = savedAerobic;
      if (_resistanceWeekly == null && savedResistance != null) _resistanceWeekly = savedResistance;
      _exercisePrefillHint = hint;
    });
  }

  /// exerciseMinutes 기반 주당 세션을 설문 aerobic 값으로 매핑
  String _exerciseMinutesToSurveyAerobic(int weeklySessions) {
    if (weeklySessions == 0) return '0';
    if (weeklySessions <= 2) return '1-2';
    if (weeklySessions <= 4) return '3-4';
    return '5+';
  }

  String? _extractSurveyString(dynamic value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) return null;
    // "3-4회" 형태면 "3-4"로 정규화
    final normalized = value.replaceFirst(RegExp(r'회$'), '').trim();
    return normalized.isNotEmpty ? normalized : null;
  }

  /// 수면 설문 자동 채우기.
  /// 1) 기기 Health Connect/HealthKit 최근 7일, 2) health_data(어제), 3) 저장된 lifestyle.
  Future<void> _prefillSleepData() async {
    if (_sleepHoursWeekday != null &&
        _sleepHoursWeekend != null &&
        _sleepHoursWeekday! >= 3 &&
        _sleepHoursWeekday! <= 10 &&
        _sleepHoursWeekend! >= 3 &&
        _sleepHoursWeekend! <= 10) {
      return;
    }

    double? savedWeekday;
    double? savedWeekend;
    String? hint;

    // 1) 기기 Health Connect/HealthKit 최근 7일 (있는 날짜만 평균)
    final suggested = await SleepAutoFillService.fetchSuggestedValues();
    if (suggested != null) {
      savedWeekday = suggested.sleepHoursWeekday;
      savedWeekend = suggested.sleepHoursWeekend;
      hint = '건강 데이터에서 가져왔습니다.';
    }

    // 2) health_data(어제) - 서버 동기화 데이터
    if (savedWeekday == null || savedWeekend == null) {
      final syncedHealth = await _lifestyleService.getYesterdayHealthData();
      if (syncedHealth['success'] == true &&
          syncedHealth['data'] is Map<String, dynamic>) {
        final healthData = syncedHealth['data'] as Map<String, dynamic>;
        final sleepMinutes = _extractMetricNumber(healthData['sleepMinutes']);
        if (sleepMinutes != null && sleepMinutes > 0) {
          final hours = (sleepMinutes / 60.0).clamp(3.0, 10.0);
          final rounded = (hours * 10).round() / 10.0;
          savedWeekday ??= rounded;
          savedWeekend ??= rounded;
          hint ??= '건강 데이터에서 가져왔습니다.';
        }
      }
    }

    // 3) 저장된 lifestyle
    if (savedWeekday == null || savedWeekend == null) {
      final result = await _lifestyleService.getLifestyleData();
      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        final data = result['data'] as Map<String, dynamic>;
        final sleep = data['lifestyle']?['sleep'] ?? data['sleep'];
        if (sleep is Map<String, dynamic>) {
          savedWeekday ??= _extractMetricNumber(sleep['sleep_hours_weekday']);
          savedWeekend ??= _extractMetricNumber(sleep['sleep_hours_weekend']);
          hint ??= '이전 설문에서 저장된 정보입니다.';
        }
      }
    }

    if (savedWeekday != null && savedWeekend != null &&
        savedWeekday >= 3 && savedWeekday <= 10 &&
        savedWeekend >= 3 && savedWeekend <= 10) {
      if (!mounted) return;
      setState(() {
        _sleepHoursWeekday = savedWeekday!;
        _sleepHoursWeekend = savedWeekend!;
        _sleepPrefillHint = hint;
      });
    }
  }

  /// 회원가입 시 저장한 흡연 여부 로드. 'never'면 설문에서 흡연 섹션 숨김
  Future<void> _loadUserSmokingStatus() async {
    final result = await _profileService.getMyProfile();
    if (result['success'] != true || result['data'] is! Map<String, dynamic>) return;
    final data = result['data'] as Map<String, dynamic>;
    final status = data['smoking_status']?.toString().trim();
    if (status == 'never' && mounted) {
      setState(() {
        _userSmokingStatus = 'never';
        _smokingStatus = 'never';
        _smokingDaysPerWeek = null;
      });
    } else if (mounted) {
      setState(() {
        _userSmokingStatus = status;
        if (status == 'current' || status == 'former') {
          _smokingStatus ??= status;
        }
      });
    }
  }

  SurveyFormState _currentFormState() {
    final smokingDays = _smokingStatus == 'current' ? _smokingDaysPerWeek : null;
    return SurveyFormState(
      lifestyleId: widget.lifestyleId,
      outcomes: _outcomes,
      sleepHoursWeekday: _sleepHoursWeekday,
      sleepHoursWeekend: _sleepHoursWeekend,
      sleepQualityScore: _sleepQualityScore,
      uvExposure10to16: _uvExposure10to16,
      sunscreenFrequency: _sunscreenFrequency,
      drinkingDaysPerWeek: _drinkingDaysPerWeek,
      smokingStatus: _smokingStatus,
      smokingDaysPerWeek: smokingDays,
      stressScore: _stressScore,
      aerobicWeekly: _aerobicWeekly,
      resistanceWeekly: _resistanceWeekly,
      height: _height,
      weight: _weight,
      skinType: _skinType,
      skinSatisfaction: _skinSatisfaction,
      originalImageUrl: widget.originalImageUrl,
    );
  }

  Future<void> _submitSurvey() async {
    if (_isSubmittingSurvey) return;
    debugPrint('[SurveyScreen] 설문 데이터 제출 시작');
    setState(() => _isSubmittingSurvey = true);

    final result = await _surveyController.submitSurvey(_currentFormState());

    if (!result.success) {
      if (mounted) {
        setState(() => _isSubmittingSurvey = false);
        showErrorSnackBar(
          context,
          result.message ?? '저장에 실패했습니다.',
        );
      }
      return;
    }

    if (!mounted) return;

    final situationText = _situationTextController.text.trim();
    final situationForReport =
        situationText.isNotEmpty ? situationText : null;

    // 업로드와 같은 lifestyle면: 설문 저장 직후 GPU skin-edit (결과 화면 오른쪽)
    if (widget.lifestyleId != null) {
      showSurveyAiGeneratingDialog(context);

      final skinResult = await _lifestyleService.requestSkinEdit(
        lifestyleId: widget.lifestyleId!,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (skinResult['success'] != true && mounted) {
        debugPrint(
          '[SurveyScreen] skin-edit 실패(오른쪽은 /generate 결과만 보일 수 있음): '
          '${skinResult['message']}',
        );
        showErrorSnackBar(
          context,
          skinResult['message']?.toString() ??
              '피부 반영 이미지 생성에 실패했습니다.',
        );
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          situationText: situationForReport,
          originalImageUrl: widget.originalImageUrl,
        ),
      ),
    );
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
            SurveyProgressHeader(
              isDark: isDark,
              currentPage: _currentPage,
              totalPages: _totalPages,
              showHomeButtonOnFirstPage: widget.showHomeButtonOnFirstPage,
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
                        prefillHint: _sleepPrefillHint,
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
                        onUvExposureChanged: (value) {
                          setState(() => _uvExposure10to16 = value);
                        },
                        onSunscreenFrequencyChanged: (value) {
                          setState(() => _sunscreenFrequency = value);
                        },
                        choiceBuilder: _buildChoiceButton,
                      ),
                      SurveyAlcoholSmokingPage(
                        isDark: isDark,
                        drinkingDaysPerWeek: _drinkingDaysPerWeek,
                        smokingStatus: _smokingStatus,
                        smokingDaysPerWeek: _smokingDaysPerWeek,
                        showSmokingSection: _userSmokingStatus != 'never',
                        onDrinkingDaysChanged: (value) {
                          setState(() => _drinkingDaysPerWeek = value);
                        },
                        onSmokingStatusChanged: (value) {
                          setState(() {
                            _smokingStatus = value;
                            if (value != 'current') {
                              _smokingDaysPerWeek = null;
                            }
                          });
                        },
                        onSmokingDaysChanged: (value) {
                          setState(() => _smokingDaysPerWeek = value);
                        },
                        choiceBuilder: _buildChoiceButton,
                      ),
                      SurveyStressPage(
                        isDark: isDark,
                        stressScore: _stressScore!,
                        onStressScoreChanged: (value) {
                          setState(() => _stressScore = value);
                        },
                        sliderBuilder: _buildSliderField,
                      ),
                      SurveyActivityPage(
                        isDark: isDark,
                        aerobicWeekly: _aerobicWeekly,
                        resistanceWeekly: _resistanceWeekly,
                        height: _height,
                        weight: _weight,
                        prefillHint: _exercisePrefillHint,
                        onAerobicWeeklyChanged: (value) {
                          setState(() => _aerobicWeekly = value);
                        },
                        onResistanceWeeklyChanged: (value) {
                          setState(() => _resistanceWeekly = value);
                        },
                        onHeightChanged: (value) {
                          setState(() {
                            _heightEditedByUser = true;
                            _height = value?.toDouble();
                          });
                        },
                        onWeightChanged: (value) {
                          setState(() {
                            _weightEditedByUser = true;
                            _weight = value?.toDouble();
                          });
                        },
                        choiceBuilder: _buildChoiceButton,
                        integerFieldBuilder: _buildIntegerTextField,
                      ),
                      SurveySkinPage(
                        isDark: isDark,
                        skinType: _skinType,
                        skinSatisfaction: _skinSatisfaction!,
                        onSkinTypeChanged: (value) {
                          setState(() => _skinType = value);
                        },
                        onSkinSatisfactionChanged: (value) {
                          setState(() => _skinSatisfaction = value);
                        },
                        choiceBuilder: _buildChoiceButton,
                        sliderBuilder: _buildSliderField,
                      ),
                      SurveySummaryPage(
                        isDark: isDark,
                        situationController: _situationTextController,
                        situationTextMaxLength: _situationTextMaxLength,
                        onSubmit: _submitSurvey,
                        submitBusy: _isSubmittingSurvey,
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

}
