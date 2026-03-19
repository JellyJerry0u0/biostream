import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';
import '../services/auth_service.dart';
import 'my_info/my_info_profile_controller.dart';
import 'my_info/my_info_visibility_helper.dart';
import 'onboarding_screen.dart';
import 'past_face_archive_screen.dart';
import 'past_report_history_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/my_info/my_info_edit_profile_dialog.dart';
import '../widgets/my_info/my_info_menu_section.dart';
import '../widgets/my_info/my_info_profile_header.dart';
import '../widgets/my_info/my_info_stats_panel.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);

  final ImagePicker _imagePicker = ImagePicker();
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  late final MyInfoProfileController _profileController =
      MyInfoProfileController(
    profileService: _profileService,
    prefsProvider: SharedPreferences.getInstance,
  );
  final MyInfoVisibilityHelper _visibilityHelper = MyInfoVisibilityHelper();

  String _nickname = '김바이오';
  String _email = 'biostream@example.com';
  String? _profileImagePath;
  bool _showBlankCanvas = false;

  late final AnimationController _introCtrl;
  late final AnimationController _visibilityCtrl;
  late final Animation<double> _pageOpacity;
  late final Animation<Offset> _profileSlide;
  late final Animation<Offset> _statsSlide;
  late final Animation<Offset> _menuSlide;
  late final Animation<double> _profileOpacity;
  late final Animation<double> _statsOpacity;
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
        curve: const Interval(0.0, 0.44, curve: Curves.easeOutCubic),
      ),
    );
    _statsSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.16, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _menuSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.3, 0.92, curve: Curves.easeOutCubic),
      ),
    );
    _profileOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.44, curve: Curves.easeOut),
    );
    _statsOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.16, 0.62, curve: Curves.easeOut),
    );
    _menuOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.3, 0.92, curve: Curves.easeOut),
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

  Future<void> _loadProfile() async {
    final local = await _profileController.loadLocalProfile(
      defaultNickname: _nickname,
      defaultEmail: _email,
    );

    if (!mounted) return;
    setState(() {
      _nickname = local.nickname;
      _email = local.email;
      _profileImagePath = local.profileImagePath;
    });

    final synced =
        await _profileController.syncProfileFromServer(current: local);
    if (!mounted || synced == null) return;
    setState(() {
      _nickname = synced.nickname;
      _email = synced.email;
      _profileImagePath = synced.profileImagePath;
    });
  }

  Future<void> _saveProfile({
    required String nickname,
    required String email,
    String? profileImagePath,
  }) async {
    final saved = await _profileController.saveProfile(
      nickname: nickname,
      email: email,
      currentImagePath: _profileImagePath,
      profileImagePath: profileImagePath,
    );

    if (!mounted) return;
    setState(() {
      _nickname = saved.nickname;
      _email = saved.email;
      _profileImagePath = saved.profileImagePath;
    });
  }

  Future<void> _pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: _primary),
                title: const Text(
                  '갤러리에서 선택',
                  style: TextStyle(color: Color(0xFF102217)),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: _primary),
                title: const Text(
                  '카메라로 촬영',
                  style: TextStyle(color: Color(0xFF102217)),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (file == null) return;

    await _saveProfile(
      nickname: _nickname,
      email: _email,
      profileImagePath: file.path,
    );
  }

  Future<void> _showEditProfileDialog() async {
    final nicknameController = TextEditingController(text: _nickname);
    final emailController = TextEditingController(text: _email);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return MyInfoEditProfileDialog(
          nicknameController: nicknameController,
          emailController: emailController,
          onPickImage: _pickProfileImage,
          onCancel: () => Navigator.of(context).pop(),
          onSave: (nickname, email) async {
            if (nickname.isEmpty || email.isEmpty || !email.contains('@')) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('닉네임과 올바른 이메일을 입력해주세요.')),
              );
              return;
            }

            await _saveProfile(
              nickname: nickname,
              email: email,
            );

            if (!mounted) return;
            Navigator.of(this.context).pop();
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content: Text('수정이 완료되었습니다.')),
            );
          },
        );
      },
    );

    nicknameController.dispose();
    emailController.dispose();
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
                                email: _email,
                                profileImagePath: _profileImagePath,
                                onEditTap: _showEditProfileDialog,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SlideTransition(
                            position: _statsSlide,
                            child: FadeTransition(
                              opacity: _statsOpacity,
                              child: const MyInfoStatsPanel(),
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
                                onOpenPastFaces: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PastFaceArchiveScreen(),
                                    ),
                                  );
                                },
                                onLogout: _logout,
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
