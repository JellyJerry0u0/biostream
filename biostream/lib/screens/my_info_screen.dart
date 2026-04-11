import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';
import '../services/auth_service.dart';
import 'my_info/my_info_profile_controller.dart';
import 'my_info/my_info_visibility_helper.dart';
import 'onboarding_screen.dart';
import 'past_report_history_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/my_info/my_info_edit_profile_dialog.dart';
import '../utils/app_snackbar.dart';
import '../widgets/my_info/my_info_menu_section.dart';
import '../widgets/my_info/my_info_notification_settings_dialog.dart';
import '../widgets/my_info/my_info_profile_header.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen>
    with TickerProviderStateMixin {
  static const Color _backgroundLight = Color(0xFFF6F8F6);

  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  late final MyInfoProfileController _profileController =
      MyInfoProfileController(
    profileService: _profileService,
    prefsProvider: SharedPreferences.getInstance,
  );
  final MyInfoVisibilityHelper _visibilityHelper = MyInfoVisibilityHelper();

  String _nickname = '김바이오';
  String _userId = '';
  String _accountEmail = 'biostream@example.com';
  double? _heightCm;
  double? _weightKg;
  bool _showBlankCanvas = false;

  late final AnimationController _introCtrl;
  late final AnimationController _visibilityCtrl;
  late final Animation<double> _pageOpacity;
  late final Animation<Offset> _profileSlide;
  late final Animation<Offset> _menuSlide;
  late final Animation<double> _profileOpacity;
  late final Animation<double> _menuOpacity;

  @override
  void initState() {
    super.initState();
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
    _profileSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _menuSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.22, 0.92, curve: Curves.easeOutCubic),
      ),
    );
    _profileOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _menuOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.22, 0.92, curve: Curves.easeOut),
    );
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisibleNow = MyInfoVisibilityHelper.isMyInfoScreenVisible(context);
    final update = _visibilityHelper.handleVisibilityChange(isVisibleNow);

    if (update.visibilityValue != null) {
      _visibilityCtrl.value = update.visibilityValue!;
    }
    if (update.showBlankCanvas != null) {
      _showBlankCanvas = update.showBlankCanvas!;
    }
    if (update.shouldForward) {
      _visibilityCtrl.forward();
    }
    if (update.shouldPlayIntro) {
      _playIntroAnimation();
    }
    if (update.shouldReverse && update.reverseEpoch != null) {
      final epoch = update.reverseEpoch!;
      _visibilityCtrl.reverse().then((_) {
        if (!mounted) return;
        final isVisibleAfterReverse =
            MyInfoVisibilityHelper.isMyInfoScreenVisible(
          context,
        );
        if (_visibilityHelper.shouldShowBlankCanvasAfterReverse(
          epoch: epoch,
          isVisibleNow: isVisibleAfterReverse,
        )) {
          setState(() {
            _showBlankCanvas = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _visibilityCtrl.dispose();
    super.dispose();
  }

  void _playIntroAnimation() {
    _introCtrl.stop();
    _introCtrl.forward(from: 0);
  }

  MyInfoProfileData get _profileSnapshot => MyInfoProfileData(
        nickname: _nickname,
        userId: _userId,
        accountEmail: _accountEmail,
        heightCm: _heightCm,
        weightKg: _weightKg,
      );

  Future<void> _loadProfile() async {
    final local = await _profileController.loadLocalProfile(
      defaultNickname: _nickname,
      defaultUserId: _userId,
      defaultAccountEmail: _accountEmail,
    );

    if (!mounted) return;
    setState(() {
      _nickname = local.nickname;
      _userId = local.userId;
      _accountEmail = local.accountEmail;
      _heightCm = local.heightCm;
      _weightKg = local.weightKg;
    });

    final synced =
        await _profileController.syncProfileFromServer(current: local);
    if (!mounted || synced == null) return;
    setState(() {
      _nickname = synced.nickname;
      _userId = synced.userId;
      _accountEmail = synced.accountEmail;
      _heightCm = synced.heightCm;
      _weightKg = synced.weightKg;
    });
  }

  Future<void> _saveProfile({
    required String nickname,
    required String accountEmail,
    double? heightCm,
    double? weightKg,
  }) async {
    final saved = await _profileController.saveProfile(
      previous: _profileSnapshot,
      nickname: nickname,
      accountEmail: accountEmail,
      heightCm: heightCm,
      weightKg: weightKg,
    );

    if (!mounted) return;
    setState(() {
      _nickname = saved.nickname;
      _userId = saved.userId;
      _accountEmail = saved.accountEmail;
      _heightCm = saved.heightCm;
      _weightKg = saved.weightKg;
    });
  }

  Future<void> _showEditProfileDialog() async {
    final emailController = TextEditingController(text: _accountEmail);
    final nicknameController = TextEditingController(text: _nickname);
    final heightController = TextEditingController(
      text: _heightCm != null && _heightCm! > 0
          ? _formatNum(_heightCm!)
          : '',
    );
    final weightController = TextEditingController(
      text: _weightKg != null && _weightKg! > 0
          ? _formatNum(_weightKg!)
          : '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return MyInfoEditProfileDialog(
          emailController: emailController,
          nicknameController: nicknameController,
          heightCmController: heightController,
          weightKgController: weightController,
          onCancel: () => Navigator.of(context).pop(),
          onSave: () async {
            final nickname = nicknameController.text.trim();
            final email = emailController.text.trim();
            if (nickname.isEmpty || email.isEmpty || !email.contains('@')) {
              showErrorSnackBar(
                this.context,
                '닉네임과 올바른 이메일을 입력해주세요.',
              );
              return;
            }

            final h = _parsePositiveDouble(heightController.text);
            final w = _parsePositiveDouble(weightController.text);

            await _saveProfile(
              nickname: nickname,
              accountEmail: email,
              heightCm: h,
              weightKg: w,
            );

            if (!mounted) return;
            Navigator.of(this.context).pop();
          },
        );
      },
    );

    // Dialog transition 종료 직후에도 내부 위젯이 컨트롤러를 참조할 수 있어
    // 수동 dispose는 하지 않는다.
  }

  static String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  static double? _parsePositiveDouble(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t.replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = MyInfoVisibilityHelper.isMyInfoScreenVisible(context);

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              IgnorePointer(
                ignoring: !isVisible,
                child: FadeTransition(
                  opacity: _pageOpacity,
                  child: SafeArea(
                    bottom: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        18,
                        20,
                        AppBottomNavBar.height + 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SlideTransition(
                            position: _profileSlide,
                            child: FadeTransition(
                              opacity: _profileOpacity,
                              child: MyInfoProfileHeader(
                                nickname: _nickname,
                                email: _accountEmail,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SlideTransition(
                            position: _menuSlide,
                            child: FadeTransition(
                              opacity: _menuOpacity,
                              child: MyInfoMenuSection(
                                onOpenPastReports: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PastReportHistoryScreen(),
                                    ),
                                  );
                                },
                                onEditProfile: _showEditProfileDialog,
                                onLogout: _logout,
                                onNotificationSettings: () {
                                  showMyInfoNotificationSettingsDialog(
                                    context,
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottomNavigation(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AppBottomNavBar(activeTab: AppNavTab.myInfo),
    );
  }
}
