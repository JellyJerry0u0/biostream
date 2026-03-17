// 코치 챗봇 화면 — WebSocket 스트리밍 기반
// "손 안의 피부노화 관리사" 코치 느낌 UI
//
// - 말풍선 + 스트리밍 타이핑 append
// - 어시스턴트 메시지 아래 "오늘의 액션" 버튼 / "근거 보기" 토글
// - 액션 버튼 클릭 → action 메시지 전송

import 'package:flutter/material.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import '../../utils/responsive.dart';
import '../../models/coach_models.dart';
import '../../services/coach_ws_client.dart';
import '../coach_chat/coach_chat_controller.dart';
import '../../widgets/coach/coach_chat_header.dart';
import '../../widgets/coach/coach_chat_input_bar.dart';
import '../../widgets/coach/coach_stream_chat_area.dart';

class CoachChatScreen extends StatefulWidget {
  /// 리포트 ID(lifestyle_id) — 있으면 리포트 기반 코칭
  final int? reportId;

  const CoachChatScreen({super.key, this.reportId});

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

  // 첫 진입 인트로 애니메이션
  late final AnimationController _introCtrl;
  late final Animation<Offset> _headerSlide;
  late final Animation<Offset> _bottomSlide;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _bottomOpacity;
  late final Animation<double> _centerOpacity;
  late final Animation<double> _centerScale;
  bool _wasVisibleInShell = false;

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
    _chatController.connect(reportId: widget.reportId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisibleNow = _isChatScreenVisible();
    if (isVisibleNow && !_wasVisibleInShell) {
      _playIntroAnimation();
    }
    _wasVisibleInShell = isVisibleNow;
  }

  @override
  void dispose() {
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
    );
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

    _chatController.sendUserMessage(text);
    _inputCtrl.clear();
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

  void _onToggleEngine() {
    final newEngine = _chatController.toggleEngine(_uiState.engine);
    _chatController.sendModeSwitch(newEngine);
    setState(() {
      _uiState = _uiState.copyWith(engine: newEngine);
    });
  }

  // ── 빌드 ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hp = Responsive.padding(context, 16);
    final isVisible = _isChatScreenVisible();
    final bgColor = isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6);

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
                  child: CoachChatHeader(
                    isDark: isDark,
                    horizontalPadding: hp,
                    isConnected: _uiState.isConnected,
                    engine: _uiState.engine,
                    isAssistantStreaming: _uiState.isAssistantStreaming,
                    onBack: _goHome,
                    onToggleEngine: _onToggleEngine,
                  ),
                ),
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _centerOpacity,
                  child: CoachStreamChatArea(
                    isDark: isDark,
                    horizontalPadding: hp,
                    scrollController: _scrollCtrl,
                    messages: _uiState.messages,
                    centerScale: _centerScale,
                    engine: _uiState.engine,
                    currentToolStatus: _uiState.currentToolStatus,
                    onActionTap: _onActionTap,
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
