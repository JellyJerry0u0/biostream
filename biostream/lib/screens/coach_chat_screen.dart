/// 코치 챗봇 화면 — WebSocket 스트리밍 기반
/// "손 안의 피부노화 관리사" 코치 느낌 UI
///
/// - 말풍선 + 스트리밍 타이핑 append
/// - 어시스턴트 메시지 아래 "오늘의 액션" 버튼 / "근거 보기" 토글
/// - 액션 버튼 클릭 → action 메시지 전송

import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../utils/responsive.dart';
import '../models/coach_models.dart';
import '../services/coach_ws_client.dart';

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
  final CoachWsClient _ws = CoachWsClient();

  final List<CoachChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isAssistantStreaming = false; // 현재 어시스턴트 응답 수신 중

  // 엔진 모드
  CoachEngine _engine = CoachEngine.quick;

  // 도구 실행 상태 (Deep 모드)
  ToolStatusEvent? _currentToolStatus;

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

    _setupWs();
    _ws.connect(reportId: widget.reportId);
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
    _ws.disconnect();
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

  void _setupWs() {
    _ws.onConnected = () {
      if (mounted) setState(() => _isConnected = true);
    };

    _ws.onDisconnected = () {
      if (mounted) setState(() => _isConnected = false);
    };

    _ws.onStart = (data) {
      final msgId = data['assistant_message_id'] as String? ?? '';
      final msg = CoachChatMessage(
        id: msgId,
        role: 'assistant',
        isStreaming: true,
      );
      if (mounted) {
        setState(() {
          _messages.add(msg);
          _isAssistantStreaming = true;
        });
        _scrollToBottom();
      }
    };

    _ws.onDelta = (data) {
      final msgId = data['assistant_message_id'] as String? ?? '';
      final delta = data['delta'] as String? ?? '';
      if (mounted) {
        setState(() {
          final msg = _findMessage(msgId);
          msg?.appendDelta(delta);
        });
        _scrollToBottom();
      }
    };

    _ws.onActions = (data) {
      final msgId = data['assistant_message_id'] as String? ?? '';
      final items = (data['items'] as List<dynamic>?)
              ?.map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          final msg = _findMessage(msgId);
          if (msg != null) msg.actions = items;
        });
      }
    };

    _ws.onCitations = (data) {
      final msgId = data['assistant_message_id'] as String? ?? '';
      final items = (data['items'] as List<dynamic>?)
              ?.map((e) => CitationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          final msg = _findMessage(msgId);
          if (msg != null) msg.citations = items;
        });
      }
    };

    _ws.onMemoryUpdate = (data) {
      // 메모리 업데이트는 UI에 작은 알림으로 표시 가능 (간단 처리)
      debugPrint('[CoachChat] 메모리 업데이트: ${data['items']}');
    };

    _ws.onModeInfo = (data) {
      final engine = data['engine'] as String?;
      if (mounted && engine != null) {
        setState(() {
          _engine = engine == 'deep' ? CoachEngine.deep : CoachEngine.quick;
        });
      }
    };

    _ws.onToolStatus = (data) {
      if (mounted) {
        final event = ToolStatusEvent.fromJson(data);
        setState(() {
          _currentToolStatus = event.isRunning ? event : null;
        });
      }
    };

    _ws.onDone = (data) {
      final msgId = data['assistant_message_id'] as String? ?? '';
      if (mounted) {
        setState(() {
          final msg = _findMessage(msgId);
          if (msg != null) msg.isStreaming = false;
          _isAssistantStreaming = false;
          _currentToolStatus = null;
        });
        _scrollToBottom();
      }
    };

    _ws.onError = (data) {
      final errorMsg = data['message'] as String? ?? '오류가 발생했습니다.';
      if (mounted) {
        setState(() {
          _isAssistantStreaming = false;
          // 마지막 어시스턴트 메시지에 오류 표시
          final msgId = data['assistant_message_id'] as String?;
          if (msgId != null) {
            final msg = _findMessage(msgId);
            if (msg != null) {
              msg.content += '\n\n⚠️ $errorMsg';
              msg.isStreaming = false;
            }
          }
        });
      }
    };
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

  CoachChatMessage? _findMessage(String id) {
    try {
      return _messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
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
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isAssistantStreaming) return;

    // 사용자 메시지 UI 추가
    setState(() {
      _messages.add(CoachChatMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: text,
      ));
    });
    _scrollToBottom();

    // WebSocket 전송
    _ws.sendUserMessage(text);
    _inputCtrl.clear();
  }

  void _onActionTap(ActionItem action) {
    if (_isAssistantStreaming) return;
    _ws.sendAction(action.id, payload: action.payload);
  }

  void _onQuickAction(String text) {
    _inputCtrl.text = text;
    _onSend();
  }

  void _onToggleEngine() {
    final newEngine =
        _engine == CoachEngine.quick ? CoachEngine.deep : CoachEngine.quick;
    _ws.sendModeSwitch(newEngine.name);
    // 낙관적 업데이트 (서버 mode_info로 확정됨)
    setState(() => _engine = newEngine);
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

    return WillPopScope(
      onWillPop: () async {
        _goHome();
        return false;
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
                  child: _buildHeader(isDark, hp),
                ),
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _centerOpacity,
                  child: _buildChatArea(isDark, hp),
                ),
              ),
              SlideTransition(
                position: _bottomSlide,
                child: FadeTransition(
                  opacity: _bottomOpacity,
                  child: _buildBottomBar(isDark, hp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 헤더 ──

  Widget _buildHeader(bool isDark, double hp) {
    final isDeep = _engine == CoachEngine.deep;
    final accentColor = isDeep ? const Color(0xFF7C4DFF) : const Color(0xFF37EC13);

    return Container(
      padding: EdgeInsets.only(
        top: Responsive.padding(context, 12),
        bottom: Responsive.padding(context, 12),
        left: hp,
        right: hp,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
            .withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          // 뒤로가기
          _iconButton(Icons.arrow_back, isDark, _goHome),
          const SizedBox(width: 6),
          const SizedBox(width: 8),
          // 타이틀 + 상태
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'AI Skin Coach',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 17),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isConnected ? accentColor : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isConnected ? 'Online' : 'Connecting...',
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
          const SizedBox(width: 8),
          // 모드 토글
          _buildEngineToggle(isDark, isDeep, accentColor),
        ],
      ),
    );
  }

  /// 엔진 모드 토글 위젯
  Widget _buildEngineToggle(bool isDark, bool isDeep, Color accentColor) {
    return GestureDetector(
      onTap: _isAssistantStreaming ? null : _onToggleEngine,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDeep ? Icons.psychology : Icons.bolt,
              size: 16,
              color: accentColor,
            ),
            const SizedBox(width: 4),
            Text(
              isDeep ? 'Deep' : 'Quick',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, bool isDark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  // ── 채팅 영역 ──

  Widget _buildChatArea(bool isDark, double hp) {
    if (_messages.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: EdgeInsets.symmetric(horizontal: hp, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        if (msg.role == 'user') {
          return _buildUserBubble(msg, isDark);
        } else {
          return _buildAssistantBubble(msg, isDark);
        }
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ScaleTransition(
          scale: _centerScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF37EC13).withOpacity(0.28),
                      const Color(0xFF37EC13).withOpacity(0.04),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF37EC13).withOpacity(0.26),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 34,
                  color: Color(0xFF37EC13),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AI Skin Coach',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: isDark ? Colors.white : const Color(0xFF0F1E14),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '리포트 기반 맞춤 코칭과\n생활습관 개선 팁을 제공합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 사용자 말풍선 ──

  Widget _buildUserBubble(CoachChatMessage msg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 48), // 왼쪽 여백
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF37EC13),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF37EC13).withOpacity(0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                msg.content,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 어시스턴트 말풍선 ──

  Widget _buildAssistantBubble(CoachChatMessage msg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF37EC13).withOpacity(0.15),
              border: Border.all(
                color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                width: 2,
              ),
            ),
            child: const Icon(Icons.spa, size: 18, color: Color(0xFF37EC13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이름
                Text(
                  'Skin Coach',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                // 텍스트 버블
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[100]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 메시지 텍스트
                      Text(
                        msg.content.isEmpty && msg.isStreaming
                            ? '...'
                            : msg.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      // 도구 실행 상태 (Deep 모드)
                      if (msg.isStreaming && _currentToolStatus != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFF7C4DFF).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF7C4DFF)
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: const Color(0xFF7C4DFF),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _currentToolStatus!.displayText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF7C4DFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // 스트리밍 표시
                      if (msg.isStreaming && _currentToolStatus == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: (_engine == CoachEngine.deep
                                      ? const Color(0xFF7C4DFF)
                                      : const Color(0xFF37EC13))
                                  .withOpacity(0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── 액션 버튼들 ──
                if (msg.actions.isNotEmpty && !msg.isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: msg.actions.map((a) {
                        return _ActionChip(
                          label: a.label,
                          isDark: isDark,
                          onTap: () => _onActionTap(a),
                        );
                      }).toList(),
                    ),
                  ),

                // 근거 보기는 이제 액션 버튼으로 처리됨 (RAG 사용 시에만 표시)
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 하단 입력 바 ──

  Widget _buildBottomBar(bool isDark, double hp) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
            .withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 퀵 액션 칩
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: hp, vertical: 10),
              children: [
                _QuickChip(
                  text: '오늘의 플랜',
                  isDark: isDark,
                  onTap: () => _onQuickAction('오늘 내가 실천하면 좋을 피부 관리법을 간단히 알려줘'),
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  text: '리포트 해설',
                  isDark: isDark,
                  onTap: () => _onQuickAction('내 리포트의 핵심 결과를 간단히 요약해줘'),
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  text: '수면 관리 팁',
                  isDark: isDark,
                  onTap: () => _onQuickAction('수면이 피부에 미치는 영향과 관리법을 알려줘'),
                ),
                const SizedBox(width: 8),
                _QuickChip(
                  text: '자외선 대응',
                  isDark: isDark,
                  onTap: () => _onQuickAction('자외선 차단 관리법을 알려줘'),
                ),
              ],
            ),
          ),
          // 입력 필드
          Padding(
            padding: EdgeInsets.only(
              left: hp,
              right: hp,
              bottom: Responsive.padding(context, 20),
              top: 2,
            ),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey[200]!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: '피부 건강에 대해 물어보세요...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _onSend(),
                    ),
                  ),
                  // 전송 버튼
                  Material(
                    color: _isAssistantStreaming
                        ? Colors.grey
                        : const Color(0xFF37EC13),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _isAssistantStreaming ? null : _onSend,
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        child: Icon(
                          _isAssistantStreaming ? Icons.hourglass_top : Icons.arrow_upward,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  재사용 위젯
// ══════════════════════════════════════════════

/// 액션 칩 버튼 (어시스턴트 메시지 아래)
class _ActionChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF37EC13).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF37EC13).withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37EC13),
            ),
          ),
        ),
      ),
    );
  }
}

/// 하단 퀵 액션 칩
class _QuickChip extends StatelessWidget {
  final String text;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickChip({
    required this.text,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2E18) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey[200]!,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
