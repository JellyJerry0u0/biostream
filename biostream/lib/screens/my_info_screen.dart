import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';
import 'coach_chat_screen.dart';
import 'facescan_screen.dart';
import 'future_face_compare_screen.dart';
import 'home_screen.dart';
import 'past_face_archive_screen.dart';
import 'past_report_history_screen.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  static const String _keyProfileEmail = 'profile_email';
  static const String _keyProfileNickname = 'profile_nickname';
  static const String _keyProfileImagePath = 'profile_image_path';

  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);
  static const Color _backgroundDark = Color(0xFF050C08);
  static const Color _panelDark = Color(0xFF102217);

  final ImagePicker _imagePicker = ImagePicker();
  final ProfileService _profileService = ProfileService();

  String _nickname = '김바이오';
  String _email = 'biostream@example.com';
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      _nickname =
          prefs.getString(_keyProfileNickname)?.trim().isNotEmpty == true
              ? prefs.getString(_keyProfileNickname)!.trim()
              : _nickname;
      _email = prefs.getString(_keyProfileEmail)?.trim().isNotEmpty == true
          ? prefs.getString(_keyProfileEmail)!.trim()
          : _email;
      _profileImagePath = prefs.getString(_keyProfileImagePath);
    });

    await _syncProfileFromServer();
  }

  Future<void> _syncProfileFromServer() async {
    final result = await _profileService.getMyProfile();
    if (result['success'] != true) return;

    final data = result['data'] as Map<String, dynamic>;
    final nickname = (data['nickname'] ?? '').toString().trim();
    final email = (data['email'] ?? '').toString().trim();
    final imageUrl = (data['profile_image_url'] ?? '').toString().trim();

    final prefs = await SharedPreferences.getInstance();
    if (nickname.isNotEmpty) {
      await prefs.setString(_keyProfileNickname, nickname);
    }
    if (email.isNotEmpty) {
      await prefs.setString(_keyProfileEmail, email);
    }
    if (imageUrl.isNotEmpty) {
      await prefs.setString(_keyProfileImagePath, imageUrl);
    }

    if (!mounted) return;
    setState(() {
      if (nickname.isNotEmpty) _nickname = nickname;
      if (email.isNotEmpty) _email = email;
      if (imageUrl.isNotEmpty) _profileImagePath = imageUrl;
    });
  }

  Future<void> _saveProfile({
    required String nickname,
    required String email,
    String? profileImagePath,
  }) async {
    final apiResult = await _profileService.updateMyProfile(
      nickname: nickname,
      email: email,
      profileImagePath: profileImagePath,
    );

    String resolvedNickname = nickname;
    String resolvedEmail = email;
    String? resolvedImage = profileImagePath ?? _profileImagePath;

    if (apiResult['success'] == true) {
      final data = apiResult['data'] as Map<String, dynamic>;
      final serverNickname = (data['nickname'] ?? '').toString().trim();
      final serverEmail = (data['email'] ?? '').toString().trim();
      final serverImage = (data['profile_image_url'] ?? '').toString().trim();

      if (serverNickname.isNotEmpty) resolvedNickname = serverNickname;
      if (serverEmail.isNotEmpty) resolvedEmail = serverEmail;
      if (serverImage.isNotEmpty) resolvedImage = serverImage;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfileNickname, resolvedNickname);
    await prefs.setString(_keyProfileEmail, resolvedEmail);
    if (resolvedImage != null && resolvedImage.isNotEmpty) {
      await prefs.setString(_keyProfileImagePath, resolvedImage);
    }

    if (!mounted) return;
    setState(() {
      _nickname = resolvedNickname;
      _email = resolvedEmail;
      if (resolvedImage != null && resolvedImage.isNotEmpty) {
        _profileImagePath = resolvedImage;
      }
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
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '내 정보 수정',
            style: TextStyle(color: Color(0xFF102217)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nicknameController,
                style: const TextStyle(color: Color(0xFF102217)),
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  labelStyle: TextStyle(color: Color(0xFF7A8380)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Color(0xFF102217)),
                decoration: const InputDecoration(
                  labelText: '이메일',
                  labelStyle: TextStyle(color: Color(0xFF7A8380)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickProfileImage,
                  icon: const Icon(Icons.image, color: _primary),
                  label: const Text('프로필 사진 변경',
                      style: TextStyle(color: _primary)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('취소', style: TextStyle(color: Color(0xFF7A8380))),
            ),
            ElevatedButton(
              onPressed: () async {
                final nickname = nicknameController.text.trim();
                final email = emailController.text.trim();

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
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('수정이 완료되었습니다.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _backgroundDark,
              ),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    nicknameController.dispose();
    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundLight,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 108),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileHeader(context),
                            const SizedBox(height: 22),
                            _buildStatsPanel(),
                            const SizedBox(height: 28),
                            _buildSectionTitle('활동 및 설정'),
                            const SizedBox(height: 10),
                            _buildMenuTile(
                              icon: Icons.payments,
                              title: '나의 포인트 내역',
                              subtitle: '포인트 적립 및 사용 내역 확인',
                              trailingText: '2,450 P',
                            ),
                            const SizedBox(height: 10),
                            _buildMenuTile(
                              icon: Icons.analytics,
                              title: '과거 리포트 조회',
                              subtitle: '지금까지 분석된 노화 예측 리포트',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PastReportHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildMenuTile(
                              icon: Icons.face_retouching_natural,
                              title: '과거 얼굴 조회',
                              subtitle: '생성했던 AI 미래 얼굴 아카이브',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PastFaceArchiveScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildMenuTile(
                              icon: Icons.person,
                              title: '내 정보 수정',
                              subtitle: '개인정보 및 헬스케어 목표 설정',
                            ),
                            const SizedBox(height: 10),
                            _buildMenuTile(
                              icon: Icons.notifications,
                              title: '알림 설정',
                              subtitle: '푸시 알림 및 분석 리마인더 관리',
                            ),
                            const SizedBox(height: 28),
                            Center(
                              child: TextButton(
                                onPressed: () {},
                                child: Text(
                                  '로그아웃',
                                  style: TextStyle(
                                    color: const Color(0xFF7A8380),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Text(
                                'BioStream v1.2.4',
                                style: TextStyle(
                                  color: const Color(0xFF96A09B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomNavigation(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(color: _primary.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          _roundIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              '내 정보',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF102217),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final imageValue = _profileImagePath;
    final hasImage = imageValue != null && imageValue.isNotEmpty;
    final isNetworkImage = hasImage && imageValue!.startsWith('http');
    final isLocalImage =
        hasImage && !isNetworkImage && File(imageValue!).existsSync();

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primary, width: 1.8),
                ),
                child: ClipOval(
                  child: isNetworkImage
                      ? Image.network(imageValue!, fit: BoxFit.cover)
                      : isLocalImage
                          ? Image.file(File(imageValue!), fit: BoxFit.cover)
                          : Image.network(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuDUmqMNsrWVq2zRG6oqresa9PHOXbvbCb3aoOQacp6WImb8sMY-ZGxaJBN0cB2XIfGkzhOBaj_GkXwQu9aWdpwUBygdkMl-7QQrbXKKEd1CceNN0n4JtAf7BM0lDJ6EBAlzpkJEUTfG-qfogrOiwo-9eqZAaV7VuaX3t-FTTryEOYZ_rSosFrP6VuF_Ih9UQI43XNPwgwhSX9lEEausS25jKHrnEYFw6eI-eSz0nw6CjKJTqjyBhBB4s_-5Ky7TOqjGV3hScQr1Ujw',
                              fit: BoxFit.cover,
                            ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: _showEditProfileDialog,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: _backgroundLight, width: 2),
                    ),
                    child: const Icon(Icons.edit,
                        color: _backgroundDark, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$_nickname 님',
            style: TextStyle(
              color: const Color(0xFF102217),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _email,
            style: TextStyle(
              color: _primary.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: const [
          Expanded(
            child: _StatItem(label: '리포트', value: '12', showDivider: true),
          ),
          Expanded(
            child: _StatItem(label: '미래 얼굴', value: '8', showDivider: true),
          ),
          Expanded(
            child: _StatItem(label: '연속 출석', value: '5일'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: TextStyle(
          color: const Color(0xFF7A8380),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF102217),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: const Color(0xFF7A8380),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right,
                color: const Color(0xFF96A09B),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(color: _primary.withValues(alpha: 0.14)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomNavItem(
                icon: Icons.assignment,
                label: '설문 조사',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FaceScanScreen()),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.home,
                label: '홈 화면',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.face_retouching_natural,
                label: '내 미래 얼굴',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FutureFaceCompareScreen(),
                    ),
                  );
                },
              ),
              _BottomNavItem(
                icon: Icons.chat_bubble,
                label: '챗봇',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoachChatScreen()),
                  );
                },
              ),
              const _BottomNavItem(
                icon: Icons.person,
                label: '내 정보',
                isActive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _primary.withValues(alpha: 0.08),
        ),
        child: Icon(icon, color: const Color(0xFF102217), size: 20),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.showDivider = false,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF2BEE75);

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: const Color(0xFF7A8380),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            width: 1,
            height: 34,
            color: primary.withValues(alpha: 0.18),
          ),
      ],
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2BEE75);
    final color = isActive ? primary : const Color(0xFF7A8380);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
