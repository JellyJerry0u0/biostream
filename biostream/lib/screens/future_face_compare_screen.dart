import 'package:flutter/material.dart';

import 'coach_chat_screen.dart';
import 'facescan_screen.dart';
import 'home_screen.dart';
import 'my_info_screen.dart';
import 'today_me_screen.dart';

class FutureFaceCompareScreen extends StatefulWidget {
  const FutureFaceCompareScreen({super.key});

  @override
  State<FutureFaceCompareScreen> createState() => _FutureFaceCompareScreenState();
}

class _FutureFaceCompareScreenState extends State<FutureFaceCompareScreen> {
  static const Color _primary = Color(0xFF2BEE75);

  double _sliderRatio = 0.5;
  bool _wellManaged = true;

  static const String _futureImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBZV-jDDioxTCoeHPdxBORf9Cqaeq3knCDN8yF2F2MqIwQocXv9IaY3ImcI7pjMa2irdLPRDoDDdjAvyDQAeUlWJCquXL4pXkW5NqkPtVRhlMZLnLSJCjHGa18mlQNecxsq8L56c61sI-Jk931BbBIuUgfE2cUuL637l-O6_1mEtDxXQOFehDStgd39FB1s6ephU8okbYq2XUC_hqgVdHFGypbmjqDLEY5vGd594kB7-eLuuDefiMZ20dejz2B_9gdlF9ArrZW4AY0';
  static const String _currentImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDxIxJH9oWFTxoU35FE3EcoqKP31UypIBGEyY2F8gKH2Ve3lJCkDJfhzL4P14vr233LsdCKzEfc47JFKo_fLBzrso6z_G9TitQ5JlmTwgPGCBgQvTnH9Huj9cIFctm8iTv1wkGX-YoTyuSPUaTOXl4G6sPrakvLvvcUXH-QmnQKN-mdhfTCgIKdLTY303_Q5qABRj4QhBwBTNlRBGFksz2mGPmdtzXQJIrFTWI2V0Jmfq4VsQPv6ESZy8N4GMDh3aeO5XPmf9Ix1Z0';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6);
    final textColor = isDark ? Colors.white : const Color(0xFF0F1E14);
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark, textColor),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'AI Prediction',
                              style: TextStyle(
                                color: _primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '+20년 후의 모습 변화',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '슬라이더를 움직여 노화 과정을 확인하세요',
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildComparisonSlider(isDark),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: _buildScenarioAndCards(isDark, textColor),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomNavigation(isDark),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 66),
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: _primary,
          foregroundColor: const Color(0xFF102217),
          label: const Text(
            '솔루션 보기',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.auto_awesome),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, Color textColor) {
    final topBg = (isDark ? const Color(0xFF102217) : Colors.white).withValues(alpha: 0.86);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: topBg,
        border: Border(
          bottom: BorderSide(color: _primary.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          _roundIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.of(context).pop(),
            color: textColor,
          ),
          Expanded(
            child: Text(
              '미래 얼굴 비교',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _roundIconButton(
            icon: Icons.share,
            onTap: () {},
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
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
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildComparisonSlider(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dividerX = width * _sliderRatio;

        return AspectRatio(
          aspectRatio: 3 / 4,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final localX = details.localPosition.dx.clamp(0.0, width);
              setState(() {
                _sliderRatio = localX / width;
              });
            },
            onTapDown: (details) {
              final localX = details.localPosition.dx.clamp(0.0, width);
              setState(() {
                _sliderRatio = localX / width;
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(_futureImageUrl, fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: dividerX,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: _sliderRatio,
                        child: SizedBox(
                          width: width,
                          child: Image.network(_currentImageUrl, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: dividerX - 1,
                    child: Container(
                      width: 2,
                      color: _primary,
                    ),
                  ),
                  Positioned(
                    left: dividerX - 22,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.6),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.unfold_more,
                          color: Color(0xFF102217),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _labelChip('현재 (2024)', Colors.white),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _labelChip('미래 (2044)', _primary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _labelChip(String text, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF102217).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildScenarioAndCards(bool isDark, Color textColor) {
    final panelBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _scenarioButton(
                  icon: Icons.verified_user,
                  label: '관리 잘했을 때',
                  active: _wellManaged,
                  onTap: () => setState(() => _wellManaged = true),
                ),
              ),
              Expanded(
                child: _scenarioButton(
                  icon: Icons.warning_amber,
                  label: '관리가 부족할 때',
                  active: !_wellManaged,
                  onTap: () => setState(() => _wellManaged = false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _analysisCard(
                bgColor: panelBg,
                title: '피부 탄력 유지',
                value: _wellManaged ? '82%' : '61%',
                valueColor: _primary,
                trailing: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _analysisCard(
                bgColor: panelBg,
                title: '예상 주름 깊이',
                value: _wellManaged ? '-12%' : '+18%',
                valueColor: _wellManaged ? textColor : Colors.orangeAccent,
                trailing: _wellManaged ? Icons.remove : Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _scenarioButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final textColor = active ? const Color(0xFF102217) : Colors.white70;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisCard({
    required Color bgColor,
    required String title,
    required String value,
    required Color valueColor,
    required IconData trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(trailing, color: valueColor, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    final navBg = (isDark ? const Color(0xFF102217) : Colors.white).withValues(alpha: 0.95);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: _primary.withValues(alpha: 0.14))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomNavItem(
            icon: Icons.timer,
            label: '오늘의 나',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TodayMeScreen()),
              );
            },
          ),
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
          const _BottomNavItem(
            icon: Icons.face_retouching_natural,
            label: '내 미래 얼굴',
            isActive: true,
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
          _BottomNavItem(
            icon: Icons.person,
            label: '내 정보',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyInfoScreen()),
              );
            },
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
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
