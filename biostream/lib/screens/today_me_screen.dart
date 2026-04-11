import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/lifestyle_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/today_me/today_me_backdated_lifestyle_sheet.dart';
import '../utils/app_snackbar.dart';
import '../widgets/today_me/today_me_content.dart';
import '../widgets/today_me/today_me_lifestyle_item_editor.dart';
import 'today_me/today_me_controller.dart';
import 'today_me/today_me_models.dart';

class TodayMeScreen extends StatefulWidget {
  const TodayMeScreen({super.key});

  @override
  State<TodayMeScreen> createState() => _TodayMeScreenState();
}

class _TodayMeScreenState extends State<TodayMeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const MethodChannel _devChannel =
      MethodChannel('com.example.biostream/dev');
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);

  static const String _prefDashboardUnlockedDate =
      'today_me_dashboard_unlocked_date';
  static const String _prefLifestyleCollapsedDate =
      'today_me_lifestyle_collapsed_date';

  bool _wasVisibleInShell = false;
  bool _didInitVisibility = false;
  bool _showBlankCanvas = false;
  int _visibilityEpoch = 0;
  final LifestyleService _lifestyleService = LifestyleService();
  late final TodayMeController _controller;
  late List<TodayLifestyleItem> _todayLifestyleItems;
  String? _lifestyleNotice;
  List<LifestyleHistoryDay> _lifestyleHistory = [];
  bool _didSyncRetry = false;

  /// 오늘 스냅샷이 없을 때만 쓰임. 핫 리스타트 시 초기화되어 안내 카드가 다시 뜸.
  bool _lifestyleIntroDismissedThisSession = false;
  bool _dashboardUnlockedToday = false;
  bool _lifestyleSectionExpanded = true;
  /// 서버 오늘 날짜 스냅샷 행 존재. null 이면 첫 로드 전.
  bool? _hasTodayDailySnapshot;
  /// 오늘 스냅샷 8영역 완료. null 이면 첫 로드 전(인트로·대시보드 게이트 미적용).
  bool? _snapshotComplete;
  /// 서버 일별 스냅샷이 있는 날짜 키(YYYY-MM-DD). 주간 7칸 색칠용.
  Set<String> _savedSnapshotDateKeys = {};

  late final AnimationController _introCtrl;
  late final AnimationController _visibilityCtrl;
  late final Animation<Offset> _headerSlide;
  late final Animation<Offset> _carouselSlide;
  late final Animation<Offset> _metricsSlide;
  late final Animation<double> _pageOpacity;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _carouselOpacity;
  late final Animation<double> _metricsOpacity;

  static const List<TodayLifestyleItem> _defaultLifestyleItems = [
    TodayLifestyleItem(key: 'drinking', icon: Icons.local_bar, label: '음주', value: '-', unit: ''),
    TodayLifestyleItem(key: 'smoking', icon: Icons.smoking_rooms, label: '흡연', value: '-', unit: ''),
    TodayLifestyleItem(key: 'stress', icon: Icons.psychology, label: '스트레스', value: '-', unit: ''),
    TodayLifestyleItem(key: 'sleep', icon: Icons.bedtime, label: '수면', value: '-', unit: ''),
    TodayLifestyleItem(key: 'sleep_quality', icon: Icons.bedtime_outlined, label: '수면의 질', value: '-', unit: '/10'),
    TodayLifestyleItem(key: 'uv_outdoor', icon: Icons.wb_sunny_outlined, label: '코어시간 외출', value: '-', unit: ''),
    TodayLifestyleItem(key: 'sunscreen', icon: Icons.filter_drama_outlined, label: '선크림', value: '-', unit: ''),
    TodayLifestyleItem(key: 'exercise', icon: Icons.fitness_center, label: '운동', value: '유산소 0회 / 근력 0회', unit: '30분+'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TodayMeController(lifestyleService: _lifestyleService);
    _todayLifestyleItems = List<TodayLifestyleItem>.from(_defaultLifestyleItems);
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );
    _visibilityCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _pageOpacity = CurvedAnimation(
      parent: _visibilityCtrl,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.46, curve: Curves.easeOutCubic),
      ),
    );
    _carouselSlide = Tween<Offset>(
      begin: const Offset(-0.12, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.12, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _metricsSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.3, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _headerOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.46, curve: Curves.easeOut),
    );
    _carouselOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.12, 0.62, curve: Curves.easeOut),
    );
    _metricsOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.3, 0.78, curve: Curves.easeOut),
    );
    WidgetsBinding.instance.addObserver(this);
    _loadTodayLifestyle();
    _checkAndSaveYesterdayOnResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _introCtrl.dispose();
    _visibilityCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_snapshotComplete == false) {
        setState(() => _lifestyleIntroDismissedThisSession = false);
      }
      _checkAndSaveYesterdayOnResume();
      _loadTodayLifestyle(); // Health 등 오늘 데이터가 바뀌었을 수 있으므로 재조회
    }
  }

  Future<void> _checkAndSaveYesterdayOnResume() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getString('today_lifestyle_cache');
    final cacheDate = prefs.getString('today_lifestyle_cache_date');
    if (cache == null || cacheDate == null) return;

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (cacheDate == todayStr) return;

    try {
      final data = jsonDecode(cache) as Map<String, dynamic>;
      await _lifestyleService.saveDailyLifestyleSnapshot(
        date: cacheDate,
        drinkingDaysPerWeek: data['drinkingDaysPerWeek']?.toString(),
        smokingStatus: data['smokingStatus']?.toString(),
        stressScore: (data['stressScore'] as num?)?.toDouble(),
        sleepMinutes: (data['sleepMinutes'] as num?)?.toInt(),
        sleepQualityScore: (data['sleepQualityScore'] as num?)?.toDouble(),
        aerobicSessions30min: (data['aerobicSessions30min'] as num?)?.toInt(),
        resistanceSessions30min: (data['resistanceSessions30min'] as num?)?.toInt(),
        uvOutdoor10to16: data['uvOutdoor10to16']?.toString(),
        sunscreenApplied: data['sunscreenApplied'] as bool?,
      );
      await prefs.remove('today_lifestyle_cache');
      await prefs.remove('today_lifestyle_cache_date');
    } catch (_) {}
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _todayDateStr() {
    final n = DateTime.now();
    return _dateKey(DateTime(n.year, n.month, n.day));
  }

  /// 표시 칸이 모두 찼는지 (기기 건강으로만 채운 수면·운동 포함)
  bool _lifestyleGridLooksComplete(List<TodayLifestyleItem> items) {
    for (final x in items) {
      final v = x.value.trim();
      if (v.isEmpty || v == '-') return false;
    }
    return true;
  }

  /// 서버 완료 또는 오늘 스냅샷 행이 있고 UI상 전 칸이 찬 경우
  bool get _lifestyleEffectiveComplete {
    if (_snapshotComplete == true) return true;
    if (_hasTodayDailySnapshot == true &&
        _lifestyleGridLooksComplete(_todayLifestyleItems)) {
      return true;
    }
    return false;
  }

  bool get _showLifestyleIntroBlur {
    if (_snapshotComplete == null) return false;
    if (_lifestyleEffectiveComplete) return false;
    return !_lifestyleIntroDismissedThisSession;
  }

  /// 주간 대시보드: 당일 해제 + (서버 완료 또는 그리드상 완료)
  bool get _showDashboardCharts =>
      _dashboardUnlockedToday && _lifestyleEffectiveComplete;

  void _persistMaskDismissed() {
    if (mounted) setState(() => _lifestyleIntroDismissedThisSession = true);
  }

  Future<void> _onLifestyleSectionExpandedChanged(bool expanded) async {
    final p = await SharedPreferences.getInstance();
    final td = _todayDateStr();
    if (expanded) {
      await p.remove(_prefLifestyleCollapsedDate);
    } else {
      await p.setString(_prefLifestyleCollapsedDate, td);
    }
    if (mounted) setState(() => _lifestyleSectionExpanded = expanded);
  }

  Future<void> _showLifestyleRecordCompleteDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: _primary, size: 56),
              const SizedBox(height: 18),
              const Text(
                '오늘의 생활습관이 기록되었습니다!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF102217),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '오늘의 생활습관은 하단에서 언제든 수정할 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: const Color(0xFF102217),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    final p = await SharedPreferences.getInstance();
    final td = _todayDateStr();
    await p.setString(_prefDashboardUnlockedDate, td);
    await p.setString(_prefLifestyleCollapsedDate, td);
    setState(() {
      _dashboardUnlockedToday = true;
      _lifestyleSectionExpanded = false;
    });
  }

  List<LifestyleHistoryDay> _mergeHistoryWithToday(
    List<LifestyleHistoryDay> server,
    LifestyleHistoryDay? today,
  ) {
    if (today == null) return server;
    final m = <String, LifestyleHistoryDay>{};
    for (final h in server) {
      m[_dateKey(h.date)] = h;
    }
    m[_dateKey(today.date)] = today;
    final out = m.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  Future<void> _loadTodayLifestyle({bool afterManualSave = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final td = _todayDateStr();
    final collapsed = prefs.getString(_prefLifestyleCollapsedDate) == td;

    final wasCompleteBeforeLoad = _snapshotComplete == true;
    final hadSnapBeforeLoad = _hasTodayDailySnapshot == true;
    final hist90 = await _controller.loadLifestyleHistory(days: 90);
    final result = await _controller.loadTodayLifestyle();
    if (!mounted) return;
    final merged = _mergeHistoryWithToday(hist90, result.todayHistoryRow);
    final hasSnap = result.hasTodayDailySnapshot;
    final complete = result.snapshotComplete;
    // 서버가 아직 완료가 아닌데 대시보드 해제 pref만 남은 경우(스냅샷 삭제·재기록 등) → 팝업이 스킵되므로 pref 제거
    var dashboardUnlockedForToday =
        prefs.getString(_prefDashboardUnlockedDate) == td;
    if (!complete && dashboardUnlockedForToday) {
      await prefs.remove(_prefDashboardUnlockedDate);
      dashboardUnlockedForToday = false;
    }

    final snapKeys = hist90.map((e) => _dateKey(e.date)).toSet();
    if (hasSnap == true) snapKeys.add(td);
    if (hasSnap == false) snapKeys.remove(td);

    setState(() {
      _lifestyleNotice = result.notice;
      if (result.items != null) {
        _todayLifestyleItems = result.items!;
      }
      _lifestyleHistory = merged;
      _savedSnapshotDateKeys = snapKeys;
      _dashboardUnlockedToday = dashboardUnlockedForToday;
      _lifestyleSectionExpanded = !collapsed;
      _hasTodayDailySnapshot = hasSnap;
      _snapshotComplete = complete;
      if ((wasCompleteBeforeLoad && !complete) ||
          (hadSnapBeforeLoad && !hasSnap)) {
        _lifestyleIntroDismissedThisSession = false;
      }
    });

    // 서버에서 snapshotComplete일 때만 자동 해제 (그리드만 찬 경우는 저장 후 팝업 경로로)
    if (!afterManualSave && complete && !dashboardUnlockedForToday) {
      await prefs.setString(_prefDashboardUnlockedDate, td);
      if (mounted) setState(() => _dashboardUnlockedToday = true);
    }
  }

  void _onLifestyleItemTap(TodayLifestyleItem item) {
    _showEditDialog(item);
  }

  void _replaceLifestyleItem(TodayLifestyleItem updated) {
    final idx = _todayLifestyleItems.indexWhere((e) => e.key == updated.key);
    if (idx < 0) return;
    setState(() {
      _todayLifestyleItems = [
        for (var i = 0; i < _todayLifestyleItems.length; i++)
          i == idx ? updated : _todayLifestyleItems[i],
      ];
    });
  }

  Future<void> _openBackdatedLifestyleEditor(DateTime day) async {
    await showTodayMeBackdatedLifestyleSheet(
      context: context,
      recordDate: day,
      controller: _controller,
      primaryColor: _primary,
      onSaved: () => _loadTodayLifestyle(afterManualSave: true),
    );
  }

  Future<void> _onSaveLifestyleBatch() async {
    if (_showLifestyleIntroBlur) return;

    final wasServerCompleteBefore = _snapshotComplete == true;
    final dateStr = _todayDateStr();

    final batchResult = await _controller.saveSnapshotBatchFromItems(
      date: dateStr,
      items: _todayLifestyleItems,
    );
    final batchOk = batchResult['success'] == true;

    if (!batchOk) {
      if (mounted) {
        showErrorSnackBar(context, '저장에 실패했습니다. 다시 시도해 주세요.');
      }
      return;
    }

    if (batchResult['first_daily_snapshot_today'] == true) {
      // 백그라운드 코치 생성이 끝날 때까지 잠시 뒤 알림(넛지가 비어 있으면 챗봇에서 재시도)
      Future<void>.delayed(const Duration(seconds: 8), () async {
        await NotificationService.instance.showCoachSnapshotNudge();
      });
    }

    await _loadTodayLifestyle(afterManualSave: true);
    if (!mounted) return;
    if (_dashboardUnlockedToday) return;
    if (_snapshotComplete != true) return;
    if (wasServerCompleteBefore) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefDashboardUnlockedDate, _todayDateStr());
      if (mounted) setState(() => _dashboardUnlockedToday = true);
      return;
    }
    await _showLifestyleRecordCompleteDialog();
  }

  Future<void> _showEditDialog(TodayLifestyleItem item) async {
    final updated = await runTodayMeLifestyleItemEditor(
      context: context,
      item: item,
      valueForEditResult: _controller.displayValueForEditResult,
    );
    if (updated != null && mounted) {
      _replaceLifestyleItem(updated);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisibleNow = _isTodayScreenVisible();

    if (!_didInitVisibility) {
      _didInitVisibility = true;
      if (isVisibleNow) {
        _showBlankCanvas = false;
        _visibilityCtrl.value = 1;
        _playIntroAnimation();
      } else {
        _showBlankCanvas = true;
        _visibilityCtrl.value = 0;
      }
      _wasVisibleInShell = isVisibleNow;
      return;
    }

    if (isVisibleNow) {
      _visibilityEpoch++;
      if (_showBlankCanvas) {
        setState(() {
          _showBlankCanvas = false;
        });
      }
      _visibilityCtrl.forward();
      if (!_wasVisibleInShell) {
        _playIntroAnimation();
      }
    } else if (_wasVisibleInShell) {
      final epoch = ++_visibilityEpoch;
      _visibilityCtrl.reverse().then((_) {
        if (!mounted || epoch != _visibilityEpoch) return;
        if (!_isTodayScreenVisible()) {
          setState(() {
            _showBlankCanvas = true;
          });
        }
      });
    }

    _wasVisibleInShell = isVisibleNow;
  }

  bool _isTodayScreenVisible() {
    final shellScope = NavShellScope.maybeOf(context);
    if (shellScope == null) {
      return true;
    }
    return shellScope.activeTab == AppNavTab.today;
  }

  void _playIntroAnimation() {
    _introCtrl.stop();
    _introCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = _isTodayScreenVisible();

    if (!isVisible && _showBlankCanvas) {
      return const Scaffold(
        backgroundColor: _backgroundLight,
        body: SafeArea(
          bottom: false,
          child: SizedBox.expand(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: !isVisible,
              child: FadeTransition(
                opacity: _pageOpacity,
                child: TodayMeContent(
                  primaryColor: _primary,
                  todayLifestyleItems: _todayLifestyleItems,
                  lifestyleHistory: _lifestyleHistory,
                  lifestyleNotice: _lifestyleNotice,
                  showLifestyleIntroBlur: _showLifestyleIntroBlur,
                  onLifestyleIntroTap: () => _persistMaskDismissed(),
                  showDashboardCharts: _showDashboardCharts,
                  lifestyleSectionExpanded: _lifestyleSectionExpanded,
                  onLifestyleSectionExpandedChanged:
                      _onLifestyleSectionExpandedChanged,
                  onLifestyleItemTap: _onLifestyleItemTap,
                  onSaveLifestyleBatch: _onSaveLifestyleBatch,
                  headerSlide: _headerSlide,
                  headerOpacity: _headerOpacity,
                  carouselSlide: _carouselSlide,
                  carouselOpacity: _carouselOpacity,
                  metricsSlide: _metricsSlide,
                  metricsOpacity: _metricsOpacity,
                  bottomPadding: AppBottomNavBar.height + 20,
                  savedSnapshotDateKeys: _savedSnapshotDateKeys,
                  onWeekEmptyDayTap: _openBackdatedLifestyleEditor,
                ),
              ),
            ),
            _buildBottomNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AppBottomNavBar(activeTab: AppNavTab.today),
    );
  }
}
