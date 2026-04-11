import 'package:flutter/material.dart';

class MyInfoMenuSection extends StatelessWidget {
  const MyInfoMenuSection({
    super.key,
    required this.onOpenPastReports,
    required this.onEditProfile,
    required this.onLogout,
    this.onNotificationSettings,
  });

  final VoidCallback onOpenPastReports;
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;
  final VoidCallback? onNotificationSettings;

  static const Color _primary = Color(0xFF2BEE75);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('활동 및 설정'),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.analytics,
          title: '과거 리포트 조회',
          subtitle: '생성일 기준으로 이전 리포트를 다시 열어봅니다',
          onTap: onOpenPastReports,
        ),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.person,
          title: '내 정보 수정',
          subtitle: '이메일·닉네임·키·몸무게',
          onTap: onEditProfile,
        ),
        const SizedBox(height: 10),
        _menuTile(
          icon: Icons.notifications,
          title: '알림 설정',
          subtitle: '푸시 알림 및 분석 리마인더 관리',
          onTap: onNotificationSettings,
        ),
        const SizedBox(height: 28),
        Center(
          child: TextButton(
            onPressed: onLogout,
            child: const Text(
              '로그아웃',
              style: TextStyle(
                color: Color(0xFF7A8380),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const Center(
          child: Text(
            'BioStream v1.2.4',
            style: TextStyle(
              color: Color(0xFF96A09B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF7A8380),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _menuTile({
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
                      style: const TextStyle(
                        color: Color(0xFF7A8380),
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
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF96A09B),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
