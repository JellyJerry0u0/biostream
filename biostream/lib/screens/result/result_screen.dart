import 'dart:async';

import 'package:flutter/material.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/responsive.dart';
import '../../services/lifestyle_service.dart';
import '../../services/habit_service.dart';
import '../../services/habit_quota.dart';
import 'result_screen_controller.dart';
import 'result_screen_helper.dart';
import 'result_screen_metrics.dart';
import '../coach/coach_chat_screen.dart';
import '../login_screen.dart';
import '../../widgets/result/result_action_buttons.dart';
import '../../widgets/result/result_aging_simulation_section.dart';
import '../../widgets/result/result_async_state_view.dart';
import '../../widgets/result/result_health_report_section.dart';
import '../../widgets/result/result_skin_edit_zero_insights.dart';
import '../../widgets/result/result_this_week_habits_section.dart';
import '../../widgets/result/result_report_content.dart';
import '../../widgets/result/result_screen_header.dart';

class ResultScreen extends StatefulWidget {
  final String? situationText;
  final String? originalImageUrl;
  /// 설정 시 저장된 리포트만 불러와 동일 UI로 표시 (generate-report 미호출).
  final int? viewOnlyLifestyleId;

  const ResultScreen({
    super.key,
    this.situationText,
    this.originalImageUrl,
    this.viewOnlyLifestyleId,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  final LifestyleService _lifestyleService = LifestyleService();
  final HabitService _habitService = HabitService();
  late final ResultScreenController _controller;
  late final AnimationController _revealAnim;
  final List<Map<String, String>> _pendingHabits = []; // [{title, detail, sectionKey}]
  int? _habitQuestMax;
  int _habitActiveCount = 0;
  Map<String, dynamic>? _lifestyleData;
  Map<String, dynamic>? _reportData; // 새로운 스키마: {tabs, sections}
  String? _originalImageUrl;
  String? _generatedImageUrl;
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  String? _errorMessage;
  String? _selectedTab; // 선택된 탭
  /// 리포트 본문(탭)을 펼쳐 보여줄지 — 전환 이후 true
  bool _reportRevealed = false;
  bool _isRevealingReport = false;

  bool get _hasNotionButton => _reportData?['notion_url'] != null;

  bool get _showAiReportCta =>
      _isGeneratingReport ||
      (_reportData != null && !_reportRevealed);

  /// 서버에 이미 있는 생활습관 + 담기 대기(pending) 합이 한도 이상이면 더 담을 수 없음
  bool get _habitQuestSlotsFull {
    final cap = _habitQuestMax;
    if (cap == null) return false;
    return _habitActiveCount + _pendingHabits.length >= cap;
  }

  Future<void> _refreshHabitQuota() async {
    final r = await _habitService.getCommittedActions();
    if (!mounted || r['success'] != true) return;
    final info = HabitQuotaInfo.tryParse(r);
    if (info == null) return;
    setState(() {
      _habitQuestMax = info.max;
      _habitActiveCount = info.activeCount;
    });
  }

  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = ResultScreenController(
      lifestyleService: _lifestyleService,
      situationText: widget.situationText,
    );
    _revealAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.originalImageUrl != null &&
        widget.originalImageUrl!.isNotEmpty) {
      ResultScreenHelper.resolveImageUrl(widget.originalImageUrl)
          .then((resolved) {
        if (!mounted || resolved == null || resolved.isEmpty) return;
        setState(() {
          _originalImageUrl = resolved;
        });
      });
    }
    if (widget.viewOnlyLifestyleId != null) {
      _loadArchivedReportOnly();
    } else {
      _loadDataAndGenerateReport();
    }
  }

  @override
  void dispose() {
    _revealAnim.dispose();
    super.dispose();
  }

  Future<void> _loadArchivedReportOnly() async {
    setState(() {
      _isLoading = true;
      _isGeneratingReport = false;
      _errorMessage = null;
      _reportRevealed = true;
      _isRevealingReport = false;
      _revealAnim.value = 1;
    });

    final id = widget.viewOnlyLifestyleId!;
    final result = await _lifestyleService.getHealthReport(id);
    if (!mounted) return;

    if (result['success'] != true || result['report'] == null) {
      setState(() {
        _errorMessage =
            (result['message'] ?? '리포트를 불러오지 못했습니다.').toString();
        _isLoading = false;
      });
      return;
    }

    Map<String, dynamic>? ld;
    final rawLd = result['lifestyle_data'];
    if (rawLd is Map) {
      ld = Map<String, dynamic>.from(rawLd);
    }
    ld ??= <String, dynamic>{};
    ld.putIfAbsent('lifestyle_id', () => id);

    final rawReport = result['report'];
    if (rawReport is! Map<String, dynamic>) {
      setState(() {
        _errorMessage = '리포트 형식이 올바르지 않습니다.';
        _isLoading = false;
      });
      return;
    }

    final cards = result['cards'];
    Map<String, dynamic> reportData;
    if (rawReport.containsKey('tabs') && rawReport.containsKey('sections')) {
      reportData = Map<String, dynamic>.from(rawReport);
    } else {
      reportData = ResultScreenHelper.convertOldSchemaToNew(
        rawReport,
        cards is List ? cards : null,
      );
    }

    final notionUrl = result['notion_url']?.toString();
    if (notionUrl != null && notionUrl.isNotEmpty) {
      reportData['notion_url'] = notionUrl;
    }

    final orig = ResultScreenHelper.extractOriginalImageUrl(ld, reportData);
    final gen = ResultScreenHelper.extractGeneratedImageUrl(ld, reportData);
    final resolvedOrig = await ResultScreenHelper.resolveImageUrl(orig);
    final resolvedGen = await ResultScreenHelper.resolveImageUrl(gen);

    final tabs = reportData['tabs'] as List<dynamic>? ?? [];
    final selectedTab =
        tabs.isNotEmpty ? tabs.first.toString() : _selectedTab;

    if (!mounted) return;
    await _refreshHabitQuota();
    if (!mounted) return;
    setState(() {
      _lifestyleData = ld;
      _reportData = reportData;
      _originalImageUrl = resolvedOrig ?? _originalImageUrl;
      _generatedImageUrl = resolvedGen ?? _generatedImageUrl;
      _selectedTab = selectedTab;
      _isLoading = false;
      _isGeneratingReport = false;
      _reportRevealed = true;
      _errorMessage = null;
    });
  }

  Future<void> _loadDataAndGenerateReport() async {
    setState(() {
      _isLoading = true;
      _isGeneratingReport = false;
      _errorMessage = null;
      _reportRevealed = false;
      _isRevealingReport = false;
      _revealAnim.value = 0;
    });

    final loadResult = await _controller.loadLifestyleData();
    if (!mounted) return;

    if (!loadResult.success || loadResult.lifestyleData == null) {
      setState(() {
        _errorMessage = loadResult.errorMessage ?? '데이터를 불러올 수 없습니다.';
        _isLoading = false;
      });
      return;
    }

    await _refreshHabitQuota();

    setState(() {
      _lifestyleData = loadResult.lifestyleData;
      _originalImageUrl = loadResult.originalImageUrl ?? _originalImageUrl;
      _generatedImageUrl = loadResult.generatedImageUrl ?? _generatedImageUrl;
      _isLoading = false;
      _isGeneratingReport = true;
    });

    await _generateHealthReport();
  }

  Future<void> _generateHealthReport({bool force = false}) async {
    if (force) {
      setState(() {
        _reportRevealed = false;
        _isRevealingReport = false;
        _revealAnim.value = 0;
      });
    }
    final generateResult = await _controller.generateHealthReport(
      lifestyleData: _lifestyleData,
      currentLifestyleData: _lifestyleData,
      showRegenerateDialog: _showRegenerateDialog,
      force: force,
    );
    if (!mounted) return;

    if (generateResult.tokenExpired) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    if (!generateResult.success || generateResult.reportData == null) {
      setState(() {
        _errorMessage = generateResult.errorMessage ?? '건강 리포트를 생성할 수 없습니다.';
        _isGeneratingReport = false;
      });
      if (_errorMessage != null &&
          (_errorMessage!.contains('설문조사 데이터를 찾을 수 없습니다') ||
              _errorMessage!.contains('설문조사 데이터를 불러올 수 없습니다'))) {
        showErrorSnackBar(context, _errorMessage!);
      }
      return;
    }

    setState(() {
      _lifestyleData = generateResult.lifestyleData ?? _lifestyleData;
      _reportData = generateResult.reportData;
      _originalImageUrl = generateResult.originalImageUrl ?? _originalImageUrl;
      _generatedImageUrl =
          generateResult.generatedImageUrl ?? _generatedImageUrl;
      _selectedTab = generateResult.selectedTab ?? _selectedTab;
      _isGeneratingReport = false;
      _errorMessage = null;
    });
    await _refreshHabitQuota();
  }

  Future<void> _runRevealAnimation() async {
    if (!mounted) return;
    _revealAnim.reset();
    setState(() => _isRevealingReport = true);
    await _revealAnim.forward();
    if (!mounted) return;
    setState(() {
      _isRevealingReport = false;
      _reportRevealed = true;
    });
  }

  Widget? _buildReportTabsContent(bool isDark) {
    if (_reportData == null || _selectedTab == null) return null;
    return ResultReportContent(
      reportData: _reportData,
      selectedTab: _selectedTab,
      onTabSelected: _onTabSelected,
      isDark: isDark,
      onAddToHabit: _addToPendingHabits,
      onRemoveFromHabit: _removeFromPendingHabits,
      isInPendingList: _isInPendingHabits,
      habitQuestFull: _habitQuestSlotsFull,
    );
  }

  Widget _buildRevealStrip(double contentWidth, bool isDark) {
    final tabs = _buildReportTabsContent(isDark);
    return SizedBox(
      height: 440,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            AnimatedBuilder(
              animation: _revealAnim,
              builder: (context, child) {
                final t = Curves.easeInOutCubic.transform(_revealAnim.value);
                return Transform.translate(
                  offset: Offset(-contentWidth * t, 0),
                  child: SizedBox(
                    width: contentWidth,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ResultSkinEditZeroInsights(
                        key: const ValueKey('reveal_insight'),
                        lifestyleData: _lifestyleData,
                        isDark: isDark,
                        play: false,
                      ),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _revealAnim,
              builder: (context, child) {
                final t = Curves.easeInOutCubic.transform(_revealAnim.value);
                return Transform.translate(
                  offset: Offset(contentWidth * (1 - t), 0),
                  child: SizedBox(
                    width: contentWidth,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ResultHealthReportSection(
                        isDark: isDark,
                        isGenerating: false,
                        reportContent: tabs,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showRegenerateDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2C16),
          title: const Text(
            '리포트 재생성',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            '이미 생성된 리포트가 있습니다.\n재생성 하시겠습니까?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // 아니오
              child: const Text(
                '아니오',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // 예
              child: const Text(
                '예',
                style: TextStyle(color: Color(0xFF37EC13)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 16);
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            ResultScreenHeader(
              isDark: isDark,
              horizontalPadding: horizontalPadding,
              showNotionButton: _hasNotionButton,
              onBack: () => Navigator.of(context).pop(),
              onOpenNotion: _openNotionPage,
            ),

            // Main Content
            Expanded(
              child: ResultAsyncStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isDark: isDark,
                onRetry: widget.viewOnlyLifestyleId != null
                    ? _loadArchivedReportOnly
                    : _loadDataAndGenerateReport,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      SizedBox(height: Responsive.padding(context, 8)),

                      ResultAgingSimulationSection(
                        isDark: isDark,
                        chronologicalAge:
                            ResultScreenMetrics.getCurrentAge(_lifestyleData),
                        agingHorizonYears:
                            ResultScreenMetrics.getTargetYears(_lifestyleData),
                        originalImageUrl: _originalImageUrl,
                        generatedImageUrl: _generatedImageUrl,
                      ),

                      SizedBox(height: Responsive.padding(context, 16)),

                      if (_isGeneratingReport)
                        ResultSkinEditZeroInsights(
                          key: const ValueKey('insight_loading'),
                          lifestyleData: _lifestyleData,
                          isDark: isDark,
                          play: true,
                        )
                      else if (_reportData != null &&
                          !_reportRevealed &&
                          !_isRevealingReport)
                        ResultSkinEditZeroInsights(
                          key: const ValueKey('insight_hold'),
                          lifestyleData: _lifestyleData,
                          isDark: isDark,
                          play: false,
                        )
                      else if (_isRevealingReport)
                        _buildRevealStrip(
                          MediaQuery.sizeOf(context).width -
                              horizontalPadding * 2,
                          isDark,
                        )
                      else if (_reportRevealed && _reportData != null)
                        ResultHealthReportSection(
                          isDark: isDark,
                          isGenerating: false,
                          reportContent: _buildReportTabsContent(isDark),
                        ),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SizeTransition(
                            sizeFactor: anim,
                            axisAlignment: -1,
                            child: child,
                          ),
                        ),
                        child: _showAiReportCta
                            ? Column(
                                key: const ValueKey('ai_report_cta'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                      height: Responsive.padding(context, 18)),
                                  _ResultAiReportRevealCta(
                                    isDark: isDark,
                                    isGenerating: _isGeneratingReport,
                                    isRevealing: _isRevealingReport,
                                    onPressed: !_isGeneratingReport &&
                                            _reportData != null &&
                                            !_isRevealingReport
                                        ? () =>
                                            unawaited(_runRevealAnimation())
                                        : null,
                                  ),
                                  SizedBox(
                                      height: Responsive.padding(context, 22)),
                                ],
                              )
                            : SizedBox(
                                key: const ValueKey('ai_report_cta_gone'),
                                height: 0,
                              ),
                      ),

                      // 이번주에 추가할 생활습관
                      ResultThisWeekHabitsSection(
                        isDark: isDark,
                        habits: _pendingHabits,
                        onRemove: _removeFromPendingHabits,
                        habitQuestMax: _habitQuestMax,
                        habitActiveOnServer: _habitActiveCount,
                      ),

                      SizedBox(height: Responsive.padding(context, 24)),

                      // Action Buttons
                      ResultActionButtons(
                        isDark: isDark,
                        showNotionButton: _hasNotionButton,
                        showViewActionPlan:
                            _reportRevealed && _reportData != null,
                        onViewActionPlan: _openActionPlan,
                        onOpenNotion: _openNotionPage,
                      ),

                      SizedBox(height: Responsive.padding(context, 24)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHabitQuestFullDialog() {
    if (!mounted) return;
    final rootContext = context;
    final isDark = Theme.of(rootContext).brightness == Brightness.dark;
    final cap = _habitQuestMax;
    final message = cap != null
        ? '오늘의 습관은 최대 $cap개까지 담을 수 있어요.\n홈이나 오늘의 나에서 기존 습관을 정리한 뒤 다시 시도해 주세요.'
        : '저장 한도에 도달했어요.\n홈이나 오늘의 나에서 기존 습관을 정리한 뒤 다시 시도해 주세요.';

    // 탭·잉크가 끝난 뒤 띄워 한 프레임에 레이아웃이 겹치지 않게
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showGeneralDialog<void>(
        context: rootContext,
        useRootNavigator: true,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(rootContext).modalBarrierDismissLabel,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Center(
            child: _HabitQuestFullDialogCard(
              message: message,
              isDark: isDark,
              onConfirm: () => Navigator.of(dialogContext).pop(),
            ),
          );
        },
        transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
      );
    });
  }

  void _addToPendingHabits(String title, String detail, String sectionKey) {
    final t = title.trim();
    if (t.isEmpty) return;
    if (_habitQuestSlotsFull) {
      _showHabitQuestFullDialog();
      return;
    }
    if (_pendingHabits.any((h) => (h['title'] ?? '').trim().toLowerCase() == t.toLowerCase())) {
      return;
    }
    setState(() {
      _pendingHabits.add({'title': t, 'detail': detail.trim(), 'sectionKey': sectionKey});
    });
  }

  void _removeFromPendingHabits(String title) {
    setState(() {
      _pendingHabits.removeWhere((h) => (h['title'] ?? '').trim().toLowerCase() == title.trim().toLowerCase());
    });
  }

  bool _isInPendingHabits(String title) {
    return _pendingHabits.any((h) => (h['title'] ?? '').trim().toLowerCase() == title.trim().toLowerCase());
  }

  /// pending 습관을 서버에 커밋하고 (성공여부, 새로 생성된 action ID 목록) 반환
  Future<(bool, List<int>)> _commitPendingHabits() async {
    final lifestyleId = _lifestyleData?['lifestyle_id'] as int?;
    if (lifestyleId == null || _pendingHabits.isEmpty) return (true, <int>[]);

    final newIds = <int>[];

    for (final h in _pendingHabits) {
      final title = h['title'] ?? '';
      final detail = h['detail'] ?? '';
      final sectionKey = h['sectionKey'] ?? '';
      if (title.isEmpty || sectionKey.isEmpty) continue;

      final result = await _habitService.commitAction(
        lifestyleId: lifestyleId,
        sectionKey: sectionKey,
        actionTitle: title,
        actionDetail: detail.isEmpty ? null : detail,
      );

      if (!mounted) return (false, <int>[]);
      if (result['token_expired'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return (false, <int>[]);
      }
      if (result['success'] != true) {
        showErrorSnackBar(
          context,
          result['message'] as String? ?? '습관 저장에 실패했습니다.',
        );
        return (false, <int>[]);
      }
      final committedAction = result['committed_action'] as Map<String, dynamic>?;
      final id = committedAction?['id'] as int?;
      if (id != null) newIds.add(id);
    }
    if (mounted) {
      setState(() => _pendingHabits.clear());
      await _refreshHabitQuota();
    }
    return (true, newIds);
  }

  Future<void> _openActionPlan() async {
    final (ok, newIds) = await _commitPendingHabits();
    if (!mounted || !ok) return;

    final rid = _lifestyleData?['lifestyle_id'] as int?;
    if (rid != null && _reportData != null) {
      await _controller.saveReportToServer(
        lifestyleId: rid,
        reportData: _reportData,
      );
      if (!mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CoachChatScreen(
          reportId: rid,
          isActionPlanInit: newIds.isNotEmpty,
          newCommittedActionIds: newIds,
        ),
      ),
    );
  }

  Future<void> _openNotionPage() async {
    final notionUrl = _reportData?['notion_url'];
    if (notionUrl == null || notionUrl.toString().trim().isEmpty) {
      showErrorSnackBar(context, '링크를 열 수 없습니다');
      return;
    }
    final opened = await ResultScreenHelper.openExternalUrl(
      notionUrl.toString(),
    );
    if (!opened) {
      showErrorSnackBar(context, '링크를 열 수 없습니다');
    }
  }
}

/// 설문 인사이트 아래 — 리포트 생성 대기 / 보기 진입.
class _ResultAiReportRevealCta extends StatelessWidget {
  const _ResultAiReportRevealCta({
    required this.isDark,
    required this.isGenerating,
    this.isRevealing = false,
    required this.onPressed,
  });

  final bool isDark;
  final bool isGenerating;
  /// 리포트 슬라이드 전환 중 — 버튼 유지 + 스피너·문구만 전환
  final bool isRevealing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final showSpinner = isGenerating || isRevealing;
    final label = isGenerating
        ? 'AI 리포트 생성 중입니다...'
        : isRevealing
            ? '리포트를 펼치는 중...'
            : 'AI 리포트 보기';
    const accent = Color(0xFF37EC13);
    final disabledBg =
        isDark ? const Color(0xFF2A4025) : const Color(0xFFE8EDE8);
    final disabledFg =
        isDark ? Colors.white38 : const Color(0xFF9AA399);

    return SizedBox(
      width: double.infinity,
      height: Responsive.fontSize(context, 52),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF101B0D),
          disabledBackgroundColor: disabledBg,
          disabledForegroundColor: disabledFg,
          elevation: 0,
          shadowColor: accent.withValues(alpha: isDark ? 0.22 : 0.18),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
            side: enabled
                ? BorderSide.none
                : BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFD5DCD5),
                  ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner) ...[
              SizedBox(
                width: Responsive.padding(context, 18),
                height: Responsive.padding(context, 18),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: disabledFg,
                ),
              ),
              SizedBox(width: Responsive.padding(context, 10)),
            ],
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 15.5),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.25,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (!showSpinner && enabled) ...[
              SizedBox(width: Responsive.padding(context, 8)),
              Icon(
                Icons.expand_more_rounded,
                size: Responsive.iconSize(context, 22),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HabitQuestFullDialogCard extends StatelessWidget {
  const _HabitQuestFullDialogCard({
    required this.message,
    required this.isDark,
    required this.onConfirm,
  });

  final String message;
  final bool isDark;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E3318) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1F1A);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF5C6560);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.86,
        constraints: const BoxConstraints(maxWidth: 340),
        padding: EdgeInsets.fromLTRB(
          Responsive.padding(context, 24),
          Responsive.padding(context, 28),
          Responsive.padding(context, 24),
          Responsive.padding(context, 20),
        ),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE8EDE8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: Responsive.padding(context, 40),
              color: isDark ? Colors.orange[300] : Colors.orange[800],
            ),
            SizedBox(height: Responsive.padding(context, 18)),
            Text(
              '습관을 더 담을 수 없어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 18),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.35,
                color: titleColor,
                height: 1.25,
              ),
            ),
            SizedBox(height: Responsive.padding(context, 12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: bodyColor,
              ),
            ),
            SizedBox(height: Responsive.padding(context, 24)),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF37EC13),
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.padding(context, 14),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  '확인',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 15),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
