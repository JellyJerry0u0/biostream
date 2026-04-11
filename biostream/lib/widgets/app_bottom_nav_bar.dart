import 'package:flutter/material.dart';

import '../screens/coach/coach_chat_screen.dart';
import '../screens/future_face_compare_screen.dart';
import '../screens/home_screen.dart';
import '../screens/my_info_screen.dart';
import '../screens/today_me_screen.dart';
import '../services/coach_chat_badge.dart';

enum AppNavTab { today, future, home, chatbot, myInfo }

/// 알림 탭 등에서 챗봇 탭으로 전환 (MainTabShell이 등록한 콜백 호출)
class CoachTabLauncher {
  static void Function()? _openChat;
  static bool _pendingOpenCoachTab = false;

  /// 알림으로 챗봇을 열 때마다 증가 — [CoachChatScreen]이 수신해 pending 넛지를 다시 당김.
  static final ValueNotifier<int> inboxPullNonce = ValueNotifier(0);

  static void register(void Function()? openChat) {
    _openChat = openChat;
    if (openChat != null && _pendingOpenCoachTab) {
      _pendingOpenCoachTab = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openChat();
        inboxPullNonce.value++;
      });
    }
  }

  static void openChatTab() {
    void run() {
      final fn = _openChat;
      if (fn != null) {
        fn();
      } else {
        _pendingOpenCoachTab = true;
      }
      inboxPullNonce.value++;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }
}

class MainTabShell extends StatefulWidget {
  const MainTabShell({super.key, this.initialTab = AppNavTab.home});

  final AppNavTab initialTab;

  @override
  State<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<MainTabShell> {
  late final PageController _pageController;
  late AppNavTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _pageController = PageController(
      initialPage: AppNavTab.values.indexOf(widget.initialTab),
    );
    CoachTabLauncher.register(() => _onTabSelected(AppNavTab.chatbot));
  }

  @override
  void dispose() {
    CoachTabLauncher.register(null);
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(AppNavTab tab) {
    if (tab == _activeTab) return;
    final targetPage = AppNavTab.values.indexOf(tab);
    // PageView 애니메이션 중에도 NavShellScope.activeTab을 즉시 맞춤.
    // 그렇지 않으면 CoachChatScreen이 isVisible=false로 빈 캔버스만 그리다가
    // 푸시로 챗봇 탭으로 온 뒤에도 대화가 비어 보일 수 있음.
    setState(() => _activeTab = tab);
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavShellScope(
      activeTab: _activeTab,
      onTabSelected: _onTabSelected,
      child: Scaffold(
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _activeTab = AppNavTab.values[index];
                });
              },
              children: const [
                TodayMeScreen(),
                FutureFaceCompareScreen(),
                HomeScreen(embedded: true),
                CoachChatScreen(),
                MyInfoScreen(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _activeTab == AppNavTab.chatbot
                    ? const Offset(0, 1)
                    : Offset.zero,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _activeTab == AppNavTab.chatbot ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: _activeTab == AppNavTab.chatbot,
                    child: ListenableBuilder(
                    listenable: CoachChatBadge.unread,
                    builder: (context, _) {
                      return AppBottomNavBar(
                        activeTab: _activeTab,
                        isHost: true,
                        coachChatUnread: CoachChatBadge.unread.value,
                      );
                    },
                  ),
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

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.activeTab,
    this.isHost = false,
    this.coachChatUnread = false,
  });

  static const double height = 88;
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _inactive = Color(0xFF7A8380);

  final AppNavTab activeTab;
  final bool isHost;
  /// 코치 메시지 미확인 시 챗봇 탭에 빨간 점
  final bool coachChatUnread;

  @override
  Widget build(BuildContext context) {
    final shellScope = NavShellScope.maybeOf(context);
    final inShell = shellScope != null;
    final effectiveTab = inShell ? shellScope.activeTab : activeTab;

    if (inShell && !isHost) {
      return const SizedBox.shrink();
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: _primary.withValues(alpha: 0.14)),
        ),
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.timer,
            label: '나의 기록',
            isActive: effectiveTab == AppNavTab.today,
            onTap: effectiveTab == AppNavTab.today
                ? null
                : () => inShell
                    ? shellScope.onTabSelected(AppNavTab.today)
                    : _navigateTo(
                        context,
                        targetTab: AppNavTab.today,
                      ),
          ),
          _NavItem(
            icon: Icons.face_retouching_natural,
            label: '시나리오 A/B',
            isActive: effectiveTab == AppNavTab.future,
            onTap: effectiveTab == AppNavTab.future
                ? null
                : () => inShell
                    ? shellScope.onTabSelected(AppNavTab.future)
                    : _navigateTo(
                        context,
                        targetTab: AppNavTab.future,
                      ),
          ),
          _NavItem(
            icon: Icons.home,
            label: '홈 화면',
            isActive: effectiveTab == AppNavTab.home,
            onTap: effectiveTab == AppNavTab.home
                ? null
                : () => inShell
                    ? shellScope.onTabSelected(AppNavTab.home)
                    : _navigateTo(
                        context,
                        targetTab: AppNavTab.home,
                      ),
          ),
          _NavItem(
            icon: Icons.chat_bubble,
            label: '챗봇',
            showUnreadDot: coachChatUnread,
            isActive: effectiveTab == AppNavTab.chatbot,
            onTap: effectiveTab == AppNavTab.chatbot
                ? null
                : () => inShell
                    ? shellScope.onTabSelected(AppNavTab.chatbot)
                    : _navigateTo(
                        context,
                        targetTab: AppNavTab.chatbot,
                      ),
          ),
          _NavItem(
            icon: Icons.person,
            label: '내 정보',
            isActive: effectiveTab == AppNavTab.myInfo,
            onTap: effectiveTab == AppNavTab.myInfo
                ? null
                : () => inShell
                    ? shellScope.onTabSelected(AppNavTab.myInfo)
                    : _navigateTo(
                        context,
                        targetTab: AppNavTab.myInfo,
                      ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(
    BuildContext context, {
    required AppNavTab targetTab,
  }) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainTabShell(initialTab: targetTab),
      ),
    );
  }
}

class NavShellScope extends InheritedWidget {
  const NavShellScope({
    super.key,
    required super.child,
    required this.activeTab,
    required this.onTabSelected,
  });

  final AppNavTab activeTab;
  final ValueChanged<AppNavTab> onTabSelected;

  static NavShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NavShellScope>();
  }

  @override
  bool updateShouldNotify(covariant NavShellScope oldWidget) {
    return oldWidget.activeTab != activeTab;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
    this.showUnreadDot = false,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final bool showUnreadDot;

  @override
  Widget build(BuildContext context) {
    const Color primary = AppBottomNavBar._primary;
    const Color inactive = AppBottomNavBar._inactive;
    final Color color = isActive ? primary : inactive;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 22),
                  if (showUnreadDot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
