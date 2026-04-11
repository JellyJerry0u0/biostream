// 코치 챗봇 화면 — WebSocket 스트리밍 기반
// "손 안의 피부노화 관리사" 코치 느낌 UI
//
// - 말풍선 + 스트리밍 타이핑 append
// - 어시스턴트 메시지 아래 "오늘의 액션" 버튼 / "근거 보기" 토글
// - 액션 버튼 클릭 → action 메시지 전송

import 'package:flutter/material.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../utils/responsive.dart';
import '../../models/coach_models.dart';
import '../../services/coach_ws_client.dart';
import '../coach_chat/coach_chat_controller.dart';
import '../../widgets/coach/coach_active_goals_sheet.dart';
import '../../widgets/coach/coach_chat_header.dart';
import '../../widgets/coach/coach_chat_input_bar.dart';
import '../../widgets/coach/coach_goal_proposals_bar.dart';
import '../../widgets/coach/coach_stream_chat_area.dart';
import '../../services/coach_inbox_service.dart';
import '../../services/coach_chat_badge.dart';
import '../../widgets/coach/coach_chat_shell_colors.dart';
import '../../widgets/coach/habit_domain_chart_section.dart';
import '../../widgets/coach/habit_personalization_bar.dart';

class CoachChatScreen extends StatefulWidget {
  /// 리포트 ID(lifestyle_id) — 있으면 리포트 기반 코칭
  final int? reportId;
  /// true이면 첫 연결 시 action_plan_init 자동 전송
  final bool isActionPlanInit;
  /// isActionPlanInit=true일 때 이번 세션에 새로 추가된 committed_action ID 목록
  final List<int> newCommittedActionIds;

  const CoachChatScreen({
    super.key,
    this.reportId,
    this.isActionPlanInit = false,
    this.newCommittedActionIds = const [],
  });

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final CoachWsClient _wsClient = CoachWsClient();
  late final CoachChatController _chatController =
      CoachChatController(wsClient: _wsClient);
  CoachChatUiState _uiState = CoachChatUiState.initial();
  bool _goalConsentBusy = false;
  bool _habitPersonalizationBusy = false;
  /// Quick→Coach 수동 전환 후 서버 브리핑 start 오기 전 플레이스홀더 제거용
  String? _coachBriefingPlaceholderId;
  bool _awaitingCoachBriefingStart = false;
  bool _coachNudgePullInFlight = false;

  // 첫 진입 인트로 애니메이션
  late final AnimationController _introCtrl;
  late final Animation<Offset> _headerSlide;
  late final Animation<Offset> _bottomSlide;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _bottomOpacity;
  late final Animation<double> _centerOpacity;
  late final Animation<double> _centerScale;
  bool _wasVisibleInShell = false;
  late final VoidCallback _inboxPullListener;

  // (citations 토글은 RAG 근거 보기 액션으로 대체됨)

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.12, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _bottomSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _headerOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.1, 0.58, curve: Curves.easeOut),
    );
    _bottomOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.16, 0.72, curve: Curves.easeOut),
    );
    _centerOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.28, 0.86, curve: Curves.easeOut),
    );
    _centerScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.26, 0.86, curve: Curves.easeOutCubic),
      ),
    );

    _bindWsCallbacks();
    // coach 모드로 시작 (action plan은 coach 엔진 필요)
    if (widget.isActionPlanInit) {
      _uiState = _uiState.copyWith(engine: CoachEngine.coach);
    }
    _chatController.connect(reportId: widget.reportId);

    _inboxPullListener = () {
      if (!mounted) return;
      if (_isChatScreenVisible() && !widget.isActionPlanInit) {
        _fetchPendingCoachNudge();
      }
    };
    CoachTabLauncher.inboxPullNonce.addListener(_inboxPullListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisibleNow = _isChatScreenVisible();
    if (isVisibleNow && !_wasVisibleInShell) {
      _playIntroAnimation();
      // 미확인(빨간 점) 상태로 들어오면 코치 모드로 열어 바로 코치 스레드 메시지가 보이게 함.
      // 배지는 여기서만 지우지 않고, 아래에서 코치 전환 적용 후 clear (알림 탭 시 hadUnread 유지).
      final hadUnread = CoachChatBadge.unread.value;
      if (hadUnread && !widget.isActionPlanInit) {
        setState(() {
          _uiState = _uiState.copyWith(engine: CoachEngine.coach);
        });
        _chatController.sendModeSwitch(CoachEngine.coach, context: 'silent_coach');
      }
      // PageView가 미리 붙어 WS는 앱 시작 시 연결됨 → onConnectedExtra 때는 넛지가 아직 없을 수 있음.
      // 챗봇 탭으로 들어올 때마다 peek 해서 스냅샷 저장 후 쌓인 메시지를 당김.
      if (!widget.isActionPlanInit) {
        _fetchPendingCoachNudge();
      }
    }
    if (isVisibleNow) {
      CoachChatBadge.clearUnread();
    }
    _wasVisibleInShell = isVisibleNow;
  }

  @override
  void dispose() {
    CoachTabLauncher.inboxPullNonce.removeListener(_inboxPullListener);
    _chatController.disconnect();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  bool _isChatScreenVisible() {
    final shellScope = NavShellScope.maybeOf(context);
    if (shellScope == null) {
      return true;
    }
    return shellScope.activeTab == AppNavTab.chatbot;
  }

  void _playIntroAnimation() {
    _introCtrl.stop();
    _introCtrl.forward(from: 0);
  }

  // ── WebSocket 콜백 설정 ──

  void _bindWsCallbacks() {
    _chatController.bindWsCallbacks(
      getState: () => _uiState,
      onStateChanged: (nextState, {scrollToBottom = false}) {
        if (!mounted) {
          return;
        }
        setState(() {
          _uiState = nextState;
        });
        if (scrollToBottom) {
          _scrollToBottom();
        }
      },
      onConnectedExtra: () {
        if (widget.isActionPlanInit) {
          _wsClient.sendModeSwitch('coach', context: 'action_plan');
          _wsClient.sendActionPlanInit(widget.newCommittedActionIds);
        } else {
          if (_uiState.engine == CoachEngine.coach) {
            _wsClient.sendModeSwitch('coach', context: 'silent_coach');
          }
          _fetchPendingCoachNudge();
        }
      },
      onAssistantStreamStarting: _onAssistantStreamStarting,
      onAssistantStreamDone: _onAssistantStreamDone,
    );
  }

  void _onAssistantStreamStarting() {
    if (!_awaitingCoachBriefingStart || _coachBriefingPlaceholderId == null) {
      return;
    }
    final id = _coachBriefingPlaceholderId!;
    _awaitingCoachBriefingStart = false;
    _coachBriefingPlaceholderId = null;
    if (!mounted) return;
    setState(() {
      _uiState = _uiState.copyWith(
        messages: _uiState.messages.where((m) => m.id != id).toList(),
      );
    });
  }

  void _onAssistantStreamDone(String assistantMessageId) {
    if (_isChatScreenVisible()) {
      return;
    }
    if (_uiState.engine != CoachEngine.coach) {
      return;
    }
    final msg = _findMessageById(assistantMessageId);
    if (msg == null || msg.channel != CoachEngine.coach) {
      return;
    }
    CoachChatBadge.markUnread();
  }

  CoachChatMessage? _findMessageById(String id) {
    for (final m in _uiState.messages) {
      if (m.id == id) {
        return m;
      }
    }
    return null;
  }

  Future<void> _fetchPendingCoachNudge() async {
    if (_coachNudgePullInFlight || widget.isActionPlanInit) {
      return;
    }
    _coachNudgePullInFlight = true;
    try {
      final nudge = await CoachInboxService.instance.peekPendingNudge();
      if (nudge == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      final id = nudge.nudgeId > 0
          ? 'coach_nudge_${nudge.nudgeId}'
          : 'coach_nudge_${DateTime.now().millisecondsSinceEpoch}';
      if (_uiState.messages.any((m) => m.id == id)) {
        await CoachInboxService.instance.consumePendingNudge();
        return;
      }
      setState(() {
        final next = List<CoachChatMessage>.from(_uiState.messages)
          ..add(
            CoachChatMessage(
              id: id,
              role: 'assistant',
              channel: CoachEngine.coach,
              content: nudge.body,
            ),
          );
        _uiState = _uiState.copyWith(
          messages: next,
          engine: CoachEngine.coach,
        );
      });
      _wsClient.sendModeSwitch('coach', context: 'silent_coach');
      _scrollToBottom();
      await CoachInboxService.instance.consumePendingNudge();
    } finally {
      _coachNudgePullInFlight = false;
    }
  }

  void _goHome() {
    final shellScope = NavShellScope.maybeOf(context);
    if (shellScope != null) {
      shellScope.onTabSelected(AppNavTab.home);
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainTabShell(initialTab: AppNavTab.home),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── 전송 ──

  void _onSend() {
    final queuedState =
        _chatController.queueUserMessage(_uiState, _inputCtrl.text);
    if (queuedState == null) {
      return;
    }
    final text = _inputCtrl.text.trim();
    setState(() {
      _uiState = queuedState;
    });
    _scrollToBottom();

    _chatController.sendUserMessage(text, engine: _uiState.engine);
    _inputCtrl.clear();
  }

  Future<void> _onGoalConsent(GoalProposalItem proposal, bool accept) async {
    final sid = _wsClient.sessionId;
    if (sid == null || sid.isEmpty) {
      if (mounted) {
        showErrorSnackBar(
          context,
          '세션이 아직 없습니다. 잠시 후 다시 시도해 주세요.',
        );
      }
      return;
    }
    setState(() => _goalConsentBusy = true);
    final result = await _chatController.submitGoalConsent(
      sessionId: sid,
      goalId: proposal.goalId,
      accept: accept,
    );
    if (!mounted) return;
    setState(() => _goalConsentBusy = false);
    final ok = result['success'] == true;
    if (ok) {
      final rest = List<GoalProposalItem>.from(_uiState.pendingGoalProposals)
        ..removeWhere((e) => e.goalId == proposal.goalId);
      setState(() {
        _uiState = _uiState.copyWith(pendingGoalProposals: rest);
      });
    } else {
      showErrorSnackBar(
        context,
        result['error']?.toString() ?? '처리하지 못했습니다.',
      );
    }
  }

  void _onActionTap(ActionItem action) {
    if (_uiState.isAssistantStreaming) {
      return;
    }
    _chatController.sendAction(action);
  }

  void _onQuickAction(String text) {
    _inputCtrl.text = text;
    _onSend();
  }

  Future<void> _onHabitAccept(HabitPersonalizationItem item) async {
    setState(() => _habitPersonalizationBusy = true);
    await _chatController.acceptPersonalization(
      item: item,
      getState: () => _uiState,
      onStateChanged: (next, {scrollToBottom = false}) {
        if (!mounted) return;
        setState(() => _uiState = next);
      },
    );
    if (mounted) setState(() => _habitPersonalizationBusy = false);
  }

  Future<void> _onHabitReject(HabitPersonalizationItem item) async {
    setState(() => _habitPersonalizationBusy = true);
    await _chatController.rejectPersonalization(
      item: item,
      getState: () => _uiState,
      onStateChanged: (next, {scrollToBottom = false}) {
        if (!mounted) return;
        setState(() => _uiState = next);
      },
    );
    if (mounted) setState(() => _habitPersonalizationBusy = false);
  }

  void _onToggleEngine() {
    final prev = _uiState.engine;
    final newEngine = _chatController.toggleEngine(prev);

    if (prev == CoachEngine.quick && newEngine == CoachEngine.coach) {
      final phId =
          'coach_briefing_placeholder_${DateTime.now().millisecondsSinceEpoch}';
      final withoutQuick = _uiState.messages
          .where((m) => m.channel != CoachEngine.quick)
          .toList();
      setState(() {
        _coachBriefingPlaceholderId = phId;
        _awaitingCoachBriefingStart = true;
        _uiState = _uiState.copyWith(
          engine: newEngine,
          messages: [
            ...withoutQuick,
            CoachChatMessage(
              id: phId,
              role: 'assistant',
              channel: CoachEngine.coach,
              content:
                  '생활·스냅샷 기준으로 인사이트를 정리하고 있어요. 잠시만 기다려 주세요…',
            ),
          ],
        );
      });
      _chatController.sendModeSwitch(newEngine);
      _scrollToBottom();
      return;
    }

    if (prev == CoachEngine.coach && newEngine == CoachEngine.quick) {
      _awaitingCoachBriefingStart = false;
      _coachBriefingPlaceholderId = null;
    }

    _chatController.sendModeSwitch(newEngine);
    setState(() {
      _uiState = _uiState.copyWith(engine: newEngine);
    });
  }

  Future<void> _openCoachActiveGoals(BuildContext context) async {
    await showCoachActiveGoalsSheet(
      context: context,
      isDark: Theme.of(context).brightness == Brightness.dark,
      engine: CoachEngine.coach,
    );
  }

  // ── 빌드 ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hp = Responsive.padding(context, 16);
    final isVisible = _isChatScreenVisible();
    final visibleMessages = _uiState.messages
        .where((m) => m.channel == _uiState.engine)
        .toList();
    final bgColor = CoachChatShellColors.scaffoldBg(
      isDark: isDark,
      engine: _uiState.engine,
    );
    final habitInsightsLoading = _uiState.engine == CoachEngine.coach &&
        _uiState.isAssistantStreaming;
    final hasHabitPanels =
        _uiState.habitDomainChartData != null ||
        _uiState.pendingHabitPersonalizations.isNotEmpty;
    final hasBottomPanels = habitInsightsLoading ||
        hasHabitPanels ||
        _uiState.pendingGoalProposals.isNotEmpty;

    // PageView 인접 페이지 프리렌더링 시 챗봇 내용을 미리 노출하지 않기 위해
    // 활성 탭이 아닐 때는 빈 캔버스만 렌더링한다.
    if (!isVisible) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const SafeArea(
          child: SizedBox.expand(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goHome();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              SlideTransition(
                position: _headerSlide,
                child: FadeTransition(
                  opacity: _headerOpacity,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: CoachChatHeader(
                      isDark: isDark,
                      horizontalPadding: hp,
                      isConnected: _uiState.isConnected,
                      engine: _uiState.engine,
                      isAssistantStreaming: _uiState.isAssistantStreaming,
                      onBack: _goHome,
                      onToggleEngine: _onToggleEngine,
                      onCoachGoalsTap: _uiState.engine == CoachEngine.coach
                          ? () => _openCoachActiveGoals(context)
                          : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  child: FadeTransition(
                    opacity: _centerOpacity,
                    child: CoachStreamChatArea(
                      isDark: isDark,
                      horizontalPadding: hp,
                      scrollController: _scrollCtrl,
                      messages: visibleMessages,
                      centerScale: _centerScale,
                      engine: _uiState.engine,
                      currentToolStatus: _uiState.currentToolStatus,
                      coachProgress: _uiState.coachProgress,
                      onActionTap: _onActionTap,
                      footer: hasBottomPanels
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: habitInsightsLoading
                                ? KeyedSubtree(
                                    key: const ValueKey(
                                        'habit_insights_loading'),
                                    child: _CoachHabitInsightsLoadingBubble(
                                      isDark: isDark,
                                    ),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey(
                                        'habit_insights_content'),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        CoachGoalProposalsBar(
                                          isDark: isDark,
                                          engine: _uiState.engine,
                                          horizontalPadding: hp,
                                          proposals: _uiState
                                              .pendingGoalProposals,
                                          isSubmitting: _goalConsentBusy,
                                          onAccept: (p) =>
                                              _onGoalConsent(p, true),
                                          onDecline: (p) =>
                                              _onGoalConsent(p, false),
                                        ),
                                        if (_uiState.habitDomainChartData !=
                                            null)
                                          HabitDomainChartSection(
                                            data: _uiState
                                                .habitDomainChartData!,
                                            accentColor:
                                                CoachChatShellColors.accent(
                                                    _uiState.engine),
                                          ),
                                        if (_uiState.habitDomainChartData !=
                                                null &&
                                            _uiState
                                                .pendingHabitPersonalizations
                                                .isNotEmpty)
                                          SizedBox(
                                              height: Responsive.padding(
                                                  context, 8)),
                                        HabitPersonalizationBar(
                                          isDark: isDark,
                                          horizontalPadding: hp,
                                          engine: _uiState.engine,
                                          items: _uiState
                                              .pendingHabitPersonalizations,
                                          isSubmitting:
                                              _habitPersonalizationBusy,
                                          onAccept: _onHabitAccept,
                                          onReject: _onHabitReject,
                                        ),
                                      ],
                                    ),
                                  ),
                          )
                        : null,
                    ),
                  ),
                ),
              ),
              SlideTransition(
                position: _bottomSlide,
                child: FadeTransition(
                  opacity: _bottomOpacity,
                  child: CoachChatInputBar(
                    isDark: isDark,
                    horizontalPadding: hp,
                    engine: _uiState.engine,
                    inputController: _inputCtrl,
                    isAssistantStreaming: _uiState.isAssistantStreaming,
                    onSend: _onSend,
                    onQuickAction: _onQuickAction,
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

/// 코치 말풍선과 같은 행 정렬, 형태만 구분되는 ‘인사이트 생성 중’ 말풍선
class _CoachHabitInsightsLoadingBubble extends StatelessWidget {
  const _CoachHabitInsightsLoadingBubble({required this.isDark});

  final bool isDark;

  static const _accent = Color(0xFF7C4DFF);

  @override
  Widget build(BuildContext context) {
    final bubbleBg = isDark
        ? const Color(0xFF1E1A2E)
        : const Color(0xFFF5F2FF);
    final bubbleBorder = _accent.withValues(alpha: isDark ? 0.45 : 0.35);
    final fg = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF3D3550);
    final sub = isDark ? Colors.white54 : const Color(0xFF7A7190);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accent.withValues(alpha: 0.18),
            border: Border.all(
              color: isDark
                  ? CoachChatShellColors.avatarRingDark(CoachEngine.coach)
                  : Colors.white,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.hub_outlined,
            size: 18,
            color: _accent.withValues(alpha: isDark ? 0.95 : 0.88),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '생활습관 인사이트',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: sub,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bubbleBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '생성 중…',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          fontWeight: FontWeight.w600,
                          color: fg,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
