import 'package:flutter/material.dart';

import '../widgets/app_bottom_nav_bar.dart';

class FutureFaceCompareScreen extends StatefulWidget {
  const FutureFaceCompareScreen({super.key});

  @override
  State<FutureFaceCompareScreen> createState() => _FutureFaceCompareScreenState();
}

class _FutureFaceCompareScreenState extends State<FutureFaceCompareScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF2BEE75);

  double _sliderRatio = 0.5;
  bool _wellManaged = true;
  bool _wasVisibleInShell = false;
  bool _didInitVisibility = false;
  bool _showBlankCanvas = false;
  int _visibilityEpoch = 0;

  late final AnimationController _introCtrl;
  late final AnimationController _visibilityCtrl;
  late final Animation<double> _pageOpacity;
  late final Animation<Offset> _heroSlide;
  late final Animation<Offset> _sliderSlide;
  late final Animation<Offset> _cardsSlide;
  late final Animation<double> _heroOpacity;
  late final Animation<double> _sliderOpacity;
  late final Animation<double> _cardsOpacity;
  late final Animation<double> _fabOpacity;

  static const String _futureImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBZV-jDDioxTCoeHPdxBORf9Cqaeq3knCDN8yF2F2MqIwQocXv9IaY3ImcI7pjMa2irdLPRDoDDdjAvyDQAeUlWJCquXL4pXkW5NqkPtVRhlMZLnLSJCjHGa18mlQNecxsq8L56c61sI-Jk931BbBIuUgfE2cUuL637l-O6_1mEtDxXQOFehDStgd39FB1s6ephU8okbYq2XUC_hqgVdHFGypbmjqDLEY5vGd594kB7-eLuuDefiMZ20dejz2B_9gdlF9ArrZW4AY0';
  static const String _currentImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDxIxJH9oWFTxoU35FE3EcoqKP31UypIBGEyY2F8gKH2Ve3lJCkDJfhzL4P14vr233LsdCKzEfc47JFKo_fLBzrso6z_G9TitQ5JlmTwgPGCBgQvTnH9Huj9cIFctm8iTv1wkGX-YoTyuSPUaTOXl4G6sPrakvLvvcUXH-QmnQKN-mdhfTCgIKdLTY303_Q5qABRj4QhBwBTNlRBGFksz2mGPmdtzXQJIrFTWI2V0Jmfq4VsQPv6ESZy8N4GMDh3aeO5XPmf9Ix1Z0';

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 860),
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
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _sliderSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.34, 0.84, curve: Curves.easeOutCubic),
      ),
    );
    _heroOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _sliderOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
    );
    _cardsOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.34, 0.84, curve: Curves.easeOut),
    );
    _fabOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisibleNow = _isFutureScreenVisible();

    if (!_didInitVisibility) {
      _didInitVisibility = true;
      if (isVisibleNow) {
        _showBlankCanvas = false;
        _visibilityCtrl.value = 1;
        _playIntroAnimation();
      } else {
        _showBlankCanvas = true;
        _visibilityCtrl.value = 0;
      }
      _wasVisibleInShell = isVisibleNow;
      return;
    }

    if (isVisibleNow) {
      _visibilityEpoch++;
      if (_showBlankCanvas) {
        setState(() {
          _showBlankCanvas = false;
        });
      }
      _visibilityCtrl.forward();
      if (!_wasVisibleInShell) {
        _playIntroAnimation();
      }
    } else if (_wasVisibleInShell) {
      final epoch = ++_visibilityEpoch;
      _visibilityCtrl.reverse().then((_) {
        if (!mounted || epoch != _visibilityEpoch) return;
        if (!_isFutureScreenVisible()) {
          setState(() {
            _showBlankCanvas = true;
          });
        }
      });
    }

    _wasVisibleInShell = isVisibleNow;
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _visibilityCtrl.dispose();
    super.dispose();
  }

  bool _isFutureScreenVisible() {
    final shellScope = NavShellScope.maybeOf(context);
    if (shellScope == null) {
      return true;
    }
    return shellScope.activeTab == AppNavTab.future;
  }

  void _playIntroAnimation() {
    _introCtrl.stop();
    _introCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6);
    final textColor = isDark ? Colors.white : const Color(0xFF0F1E14);
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final isVisible = _isFutureScreenVisible();

    if (!isVisible && _showBlankCanvas) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const SafeArea(
          bottom: false,
          child: SizedBox.expand(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IgnorePointer(
                ignoring: !isVisible,
                child: FadeTransition(
                  opacity: _pageOpacity,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SlideTransition(
                          position: _heroSlide,
                          child: FadeTransition(
                            opacity: _heroOpacity,
                            child: Padding(
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
                          ),
                        ),
                        SlideTransition(
                          position: _sliderSlide,
                          child: FadeTransition(
                            opacity: _sliderOpacity,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildComparisonSlider(isDark),
                            ),
                          ),
                        ),
                        SlideTransition(
                          position: _cardsSlide,
                          child: FadeTransition(
                            opacity: _cardsOpacity,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                              child: _buildScenarioAndCards(isDark, textColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 66),
        child: FadeTransition(
          opacity: _fabOpacity,
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

  Widget _buildBottomNavigation() {
    return const AppBottomNavBar(activeTab: AppNavTab.future);
  }
}
