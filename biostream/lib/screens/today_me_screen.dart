import 'package:flutter/material.dart';

import 'facescan_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';

class TodayMeScreen extends StatefulWidget {
  const TodayMeScreen({super.key});

  @override
  State<TodayMeScreen> createState() => _TodayMeScreenState();
}

class _TodayMeScreenState extends State<TodayMeScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);

  final PageController _pageController = PageController(viewportFraction: 0.86);
  int _activeFaceIndex = 0;
  bool _wasVisibleInShell = false;
  bool _didInitVisibility = false;
  bool _showBlankCanvas = false;
  int _visibilityEpoch = 0;

  late final AnimationController _introCtrl;
  late final AnimationController _visibilityCtrl;
  late final Animation<Offset> _headerSlide;
  late final Animation<Offset> _carouselSlide;
  late final Animation<Offset> _metricsSlide;
  late final Animation<double> _pageOpacity;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _carouselOpacity;
  late final Animation<double> _metricsOpacity;
  late final Animation<double> _recordOpacity;

  final List<_FaceCardItem> _faceCards = const [
    _FaceCardItem(
      title: 'TODAY',
      subtitle: '생성 시간: 오전 01:00',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDcE5q_Esr_MHKVrXd8SBkI7pdqDBfYtByECWmGx4SxcKr9XVzrUp0Q3onHL2Dm5HsS1to8RiOufjQkZwqT5ll6qhNJzZokn5AmOvVCafALQ6jbLKtWJ1izG1LFTlh4EsA1vlAOqH8y0X8MlQ16vWO2--WejX_JUDuX7nFapkopER4m7U4X76atduqJLTgUrsRqrD_19_UT6JuO7wM886RJKztU_K5B-mE6Gz-6O7KmUUDUS7hEicxgVMeNxyPWpqrUy8E5Cxq-Xqk',
      highlight: true,
    ),
    _FaceCardItem(
      title: 'YESTERDAY',
      subtitle: '5월 23일 (목)',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAqdPZ9vYSCR_uxbMvaZXz8CoKZk7C4HEgzibttSr0a6H0rqO9PqtmOlRhp5gNEnBf3AecYZamAOsoS577N5fqTGfoGqGW4NfMcACIek9httob2CDPOhZh1VgBC-vzT95VddwkJdPS5DXhPP8qDAF7vlIlHgcqd9jVK7c_1Kj4zpLlfJpfLY5Vv2XQNolEmv_TxBGz3_gpADtnqOdrwJKU9athsm3v21Ev1u7D1PFf_3J64GiH8obx1l3XN6Do8kqEPc9VHUwAJ_qw',
    ),
  ];

  static const List<_MetricItem> _metrics = [
    _MetricItem(icon: Icons.directions_walk, label: '거리', value: '5.2', unit: 'km'),
    _MetricItem(icon: Icons.fitness_center, label: '운동', value: '45', unit: 'min'),
    _MetricItem(icon: Icons.monitor_weight, label: '체중', value: '68.4', unit: 'kg'),
    _MetricItem(icon: Icons.opacity, label: '체지방', value: '18.2', unit: '%'),
    _MetricItem(icon: Icons.bedtime, label: '수면', value: '7.5', unit: 'hr'),
    _MetricItem(icon: Icons.restaurant, label: '영양', value: '2,100', unit: 'kcal'),
    _MetricItem(icon: Icons.air, label: '산소포화도', value: '98', unit: '%'),
    _MetricItem(icon: Icons.bloodtype, label: '혈당', value: '92', unit: 'mg/dL'),
    _MetricItem(
      icon: Icons.monitor_heart,
      label: '최대 산소 소비량 (VO2 Max)',
      value: '42.5',
      unit: 'ml/kg/min',
      wide: true,
    ),
  ];

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
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.46, curve: Curves.easeOutCubic),
      ),
    );
    _carouselSlide = Tween<Offset>(
      begin: const Offset(-0.12, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.12, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _metricsSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.3, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _headerOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.46, curve: Curves.easeOut),
    );
    _carouselOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.12, 0.62, curve: Curves.easeOut),
    );
    _metricsOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.3, 0.78, curve: Curves.easeOut),
    );
    _recordOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.56, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisibleNow = _isTodayScreenVisible();

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
        if (!_isTodayScreenVisible()) {
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
    _pageController.dispose();
    _introCtrl.dispose();
    _visibilityCtrl.dispose();
    super.dispose();
  }

  bool _isTodayScreenVisible() {
    final shellScope = NavShellScope.maybeOf(context);
    if (shellScope == null) {
      return true;
    }
    return shellScope.activeTab == AppNavTab.today;
  }

  void _playIntroAnimation() {
    _introCtrl.stop();
    _introCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = _isTodayScreenVisible();

    if (!isVisible && _showBlankCanvas) {
      return Scaffold(
        backgroundColor: _backgroundLight,
        body: const SafeArea(
          bottom: false,
          child: SizedBox.expand(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: !isVisible,
              child: FadeTransition(
                opacity: _pageOpacity,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    0,
                    AppBottomNavBar.height + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SlideTransition(
                        position: _headerSlide,
                        child: FadeTransition(
                          opacity: _headerOpacity,
                          child: _buildHeader(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SlideTransition(
                        position: _carouselSlide,
                        child: FadeTransition(
                          opacity: _carouselOpacity,
                          child: Column(
                            children: [
                              _buildFaceCarousel(),
                              _buildIndicator(),
                            ],
                          ),
                        ),
                      ),
                      SlideTransition(
                        position: _metricsSlide,
                        child: FadeTransition(
                          opacity: _metricsOpacity,
                          child: _buildMetricsPanel(),
                        ),
                      ),
                      FadeTransition(
                        opacity: _recordOpacity,
                        child: _buildRecordButton(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2024년 5월 24일',
                  style: TextStyle(
                    color: Color(0xFF7A8380),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '오늘의 나',
                  style: TextStyle(
                    color: Color(0xFF102217),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _roundIconButton(icon: Icons.calendar_today, onTap: () {}),
          const SizedBox(width: 8),
          _roundIconButton(icon: Icons.notifications_none, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildFaceCarousel() {
    return SizedBox(
      height: 470,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _faceCards.length,
        onPageChanged: (index) {
          setState(() {
            _activeFaceIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final item = _faceCards[index];
          final isActive = _activeFaceIndex == index;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: isActive ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(item.imageUrl, fit: BoxFit.cover),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.18),
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.highlight
                                  ? _primary
                                  : Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: item.highlight
                                    ? const Color(0xFF102217)
                                    : const Color(0xFF7A8380),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_faceCards.length, (index) {
          final isActive = _activeFaceIndex == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 4,
            width: isActive ? 22 : 6,
            decoration: BoxDecoration(
              color: isActive ? _primary : const Color(0xFFE3ECE7),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricsPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE8F0EB)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '어제의 나의 활동',
                        style: TextStyle(
                          color: Color(0xFF102217),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '종합 건강 지표 분석',
                        style: TextStyle(
                          color: Color(0xFF92A29B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'YESTERDAY',
                    style: TextStyle(
                      color: Color(0xFF16984B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _metrics.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.48,
              ),
              itemBuilder: (context, index) {
                final metric = _metrics[index];
                if (metric.wide) {
                  return GridTile(
                    child: _MetricCard(metric: metric),
                  );
                }
                return _MetricCard(metric: metric);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FaceScanScreen()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF102217),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: Color(0x302BEE75),
                child: Icon(Icons.add_a_photo, color: _primary),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 얼굴 기록하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '오후 세션 기록이 아직 없습니다',
                      style: TextStyle(
                        color: Color(0xFFA7B5AE),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Color(0xFFA7B5AE), size: 18),
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
      child: AppBottomNavBar(activeTab: AppNavTab.today),
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
          color: _primary.withValues(alpha: 0.09),
        ),
        child: Icon(icon, color: const Color(0xFF102217), size: 20),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricItem metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F0EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: const Color(0xFF2BEE75), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  metric.label,
                  style: const TextStyle(
                    color: Color(0xFF7A8380),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metric.value,
                style: const TextStyle(
                  color: Color(0xFF102217),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  metric.unit,
                  style: const TextStyle(
                    color: Color(0xFF96A09B),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _FaceCardItem {
  const _FaceCardItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final bool highlight;
}

class _MetricItem {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool wide;
}
