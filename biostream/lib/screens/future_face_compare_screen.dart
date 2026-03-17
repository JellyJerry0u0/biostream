import 'package:flutter/material.dart';

import '../services/lifestyle_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/future_face/future_face_comparison_slider.dart';
import '../widgets/future_face/future_face_scenario_cards.dart';
import 'future_face/future_face_compare_controller.dart';
import 'future_face/future_face_visibility_helper.dart';

class FutureFaceCompareScreen extends StatefulWidget {
  const FutureFaceCompareScreen({super.key});

  @override
  State<FutureFaceCompareScreen> createState() =>
      _FutureFaceCompareScreenState();
}

class _FutureFaceCompareScreenState extends State<FutureFaceCompareScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF2BEE75);
  final LifestyleService _lifestyleService = LifestyleService();
  late final FutureFaceCompareController _controller;
  final FutureFaceVisibilityHelper _visibilityHelper =
      FutureFaceVisibilityHelper();

  double _sliderRatio = 0.5;
  bool _wellManaged = true;
  bool _showBlankCanvas = false;

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
  String? _futureImageUrl;
  String? _currentImageUrl;
  String _simulationPromptText = '';
  bool _isLoadingImages = true;
  String? _imageError;

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
    _controller =
        FutureFaceCompareController(lifestyleService: _lifestyleService);
    _loadLatestFutureFaceImages();
  }

  Future<void> _loadLatestFutureFaceImages() async {
    setState(() {
      _isLoadingImages = true;
      _imageError = null;
    });

    final result = await _controller.loadLatestFutureFaceImages();
    if (!mounted) return;

    setState(() {
      _futureImageUrl = result.futureImageUrl;
      _currentImageUrl = result.currentImageUrl;
      _simulationPromptText = result.simulationPromptText;
      _imageError = result.errorMessage;
      _isLoadingImages = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisibleNow = FutureFaceVisibilityHelper.isFutureScreenVisible(
      context,
    );
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
        final isVisibleNow = FutureFaceVisibilityHelper.isFutureScreenVisible(
          context,
        );
        if (_visibilityHelper.shouldShowBlankCanvasAfterReverse(
          epoch: epoch,
          isVisibleNow: isVisibleNow,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6);
    final textColor = isDark ? Colors.white : const Color(0xFF0F1E14);
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final isVisible = FutureFaceVisibilityHelper.isFutureScreenVisible(context);

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
                              padding:
                                  const EdgeInsets.fromLTRB(24, 16, 24, 10),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: FutureFaceComparisonSlider(
                                isDark: isDark,
                                isLoading: _isLoadingImages,
                                currentImageUrl: _currentImageUrl,
                                futureImageUrl: _futureImageUrl,
                                imageError: _imageError,
                                sliderRatio: _sliderRatio,
                                primaryColor: _primary,
                                onSliderRatioChanged: (value) {
                                  setState(() => _sliderRatio = value);
                                },
                              ),
                            ),
                          ),
                        ),
                        SlideTransition(
                          position: _cardsSlide,
                          child: FadeTransition(
                            opacity: _cardsOpacity,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                              child: FutureFaceScenarioCards(
                                isDark: isDark,
                                textColor: textColor,
                                primaryColor: _primary,
                                wellManaged: _wellManaged,
                                simulationPromptText: _simulationPromptText,
                                onScenarioChanged: (wellManaged) {
                                  setState(() => _wellManaged = wellManaged);
                                },
                              ),
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

  Widget _buildBottomNavigation() {
    return const AppBottomNavBar(activeTab: AppNavTab.future);
  }
}
