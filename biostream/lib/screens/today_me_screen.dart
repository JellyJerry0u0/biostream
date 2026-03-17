import 'package:flutter/material.dart';

import 'facescan_screen.dart';
import '../services/lifestyle_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/today_me/today_me_content.dart';
import 'today_me/today_me_controller.dart';
import 'today_me/today_me_models.dart';

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
  final LifestyleService _lifestyleService = LifestyleService();
  late final TodayMeController _controller;
  late List<MetricItem> _metrics;
  String? _metricsNotice;

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

  final List<FaceCardItem> _faceCards = const [
    FaceCardItem(
      title: 'TODAY',
      subtitle: '생성 시간: 오전 01:00',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDcE5q_Esr_MHKVrXd8SBkI7pdqDBfYtByECWmGx4SxcKr9XVzrUp0Q3onHL2Dm5HsS1to8RiOufjQkZwqT5ll6qhNJzZokn5AmOvVCafALQ6jbLKtWJ1izG1LFTlh4EsA1vlAOqH8y0X8MlQ16vWO2--WejX_JUDuX7nFapkopER4m7U4X76atduqJLTgUrsRqrD_19_UT6JuO7wM886RJKztU_K5B-mE6Gz-6O7KmUUDUS7hEicxgVMeNxyPWpqrUy8E5Cxq-Xqk',
      highlight: true,
    ),
    FaceCardItem(
      title: 'YESTERDAY',
      subtitle: '5월 23일 (목)',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAqdPZ9vYSCR_uxbMvaZXz8CoKZk7C4HEgzibttSr0a6H0rqO9PqtmOlRhp5gNEnBf3AecYZamAOsoS577N5fqTGfoGqGW4NfMcACIek9httob2CDPOhZh1VgBC-vzT95VddwkJdPS5DXhPP8qDAF7vlIlHgcqd9jVK7c_1Kj4zpLlfJpfLY5Vv2XQNolEmv_TxBGz3_gpADtnqOdrwJKU9athsm3v21Ev1u7D1PFf_3J64GiH8obx1l3XN6Do8kqEPc9VHUwAJ_qw',
    ),
  ];

  static const List<MetricItem> _defaultMetrics = [
    MetricItem(
        icon: Icons.directions_walk, label: '거리', value: '5.2', unit: 'km'),
    MetricItem(
        icon: Icons.fitness_center, label: '운동', value: '45', unit: 'min'),
    MetricItem(
        icon: Icons.monitor_weight, label: '체중', value: '68.4', unit: 'kg'),
    MetricItem(icon: Icons.height, label: '키', value: '173.0', unit: 'cm'),
    MetricItem(icon: Icons.opacity, label: '체지방', value: '18.2', unit: '%'),
    MetricItem(
        icon: Icons.restaurant, label: '영양', value: '2100', unit: 'kcal'),
    MetricItem(icon: Icons.air, label: '산소포화도', value: '98', unit: '%'),
    MetricItem(icon: Icons.bloodtype, label: '혈당', value: '92', unit: 'mg/dL'),
    MetricItem(
      icon: Icons.monitor_heart,
      label: '최대 산소 소비량 (VO2 Max)',
      value: '42.5',
      unit: 'ml/kg/min',
      wide: true,
    ),
    MetricItem(icon: Icons.bedtime, label: '수면', value: '7.5', unit: 'hr'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TodayMeController(lifestyleService: _lifestyleService);
    _metrics = List<MetricItem>.from(_defaultMetrics);
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
    _loadYesterdayMetrics();
  }

  Future<void> _loadYesterdayMetrics() async {
    final result = await _controller.loadYesterdayMetrics();
    if (!mounted) {
      return;
    }
    setState(() {
      _metricsNotice = result.notice;
      if (result.metrics != null) {
        _metrics = result.metrics!;
      }
    });
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
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: !isVisible,
              child: FadeTransition(
                opacity: _pageOpacity,
                child: TodayMeContent(
                  primaryColor: _primary,
                  pageController: _pageController,
                  faceCards: _faceCards,
                  activeFaceIndex: _activeFaceIndex,
                  onPageChanged: (index) {
                    setState(() {
                      _activeFaceIndex = index;
                    });
                  },
                  metrics: _metrics,
                  metricsNotice: _metricsNotice,
                  onRecordTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FaceScanScreen()),
                    );
                  },
                  onCalendarTap: () {},
                  onNotificationTap: () {},
                  headerSlide: _headerSlide,
                  headerOpacity: _headerOpacity,
                  carouselSlide: _carouselSlide,
                  carouselOpacity: _carouselOpacity,
                  metricsSlide: _metricsSlide,
                  metricsOpacity: _metricsOpacity,
                  recordOpacity: _recordOpacity,
                  bottomPadding: AppBottomNavBar.height + 20,
                ),
              ),
            ),
            _buildBottomNavigation(context),
          ],
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
}
