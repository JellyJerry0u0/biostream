import 'package:flutter/material.dart';

import '../services/lifestyle_service.dart';
import '../utils/app_snackbar.dart';
import 'facescan_screen.dart';
import 'result/result_screen.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/home/home_habit_distribution_section.dart';
import '../widgets/home/home_quest_detail_dialog.dart';
import '../widgets/home/home_quest_section.dart';
import '../widgets/home/home_recent_prediction_section.dart';
import '../widgets/home/home_simulation_section.dart';
import 'home/home_models.dart';
import 'home/home_quest_controller.dart';
import 'home/home_visibility_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);
  static const Color _backgroundDark = Color(0xFF050C08);
  static const Color _gameCard = Color(0xFF0D1F14);

  final LifestyleService _lifestyleService = LifestyleService();
  late final HomeQuestController _questController;
  final HomeVisibilityHelper _visibilityHelper = HomeVisibilityHelper();

  bool _isLoadingQuests = true;
  String? _questError;
  int? _lifestyleId;
  List<HomeQuestItem> _questItems = [];
  String? _originalImageUrl;
  String? _generatedImageUrl;
  String? _predictionPoint;
  Map<String, dynamic>? _reportSummaryData;
  bool _showBlankCanvas = false;

  late final AnimationController _introCtrl;
  late final AnimationController _visibilityCtrl;
  late final Animation<double> _pageOpacity;
  late final Animation<Offset> _engineSlide;
  late final Animation<Offset> _simulationSlide;
  late final Animation<Offset> _recentSlide;
  late final Animation<Offset> _questSlide;
  late final Animation<double> _engineOpacity;
  late final Animation<double> _simulationOpacity;
  late final Animation<double> _recentOpacity;
  late final Animation<double> _questOpacity;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
    _engineSlide = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
      ),
    );
    _simulationSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.1, 0.56, curve: Curves.easeOutCubic),
      ),
    );
    _recentSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.24, 0.76, curve: Curves.easeOutCubic),
      ),
    );
    _questSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.4, 0.96, curve: Curves.easeOutCubic),
      ),
    );
    _engineOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
    );
    _simulationOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.1, 0.56, curve: Curves.easeOut),
    );
    _recentOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.24, 0.76, curve: Curves.easeOut),
    );
    _questOpacity = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _questController = HomeQuestController(lifestyleService: _lifestyleService);
    _loadQuestFromReport();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisibleNow = HomeVisibilityHelper.isHomeScreenVisible(context);
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
        final isVisibleAfterReverse = HomeVisibilityHelper.isHomeScreenVisible(
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

  Future<void> _loadQuestFromReport() async {
    setState(() {
      _isLoadingQuests = true;
      _questError = null;
    });

    final result = await _questController.loadQuestFromReport();
    if (!mounted) return;

    setState(() {
      _lifestyleId = result.lifestyleId;
      _questItems = result.questItems;
      _originalImageUrl = result.originalImageUrl;
      _generatedImageUrl = result.generatedImageUrl;
      _predictionPoint = result.predictionPoint;
      _reportSummaryData = result.summaryData;
      _isLoadingQuests = false;
      _questError = result.success ? null : result.errorMessage;
    });
  }

  Future<void> _setQuestItemDone(HomeQuestItem item, bool done) async {
    if (item.isDone == done) return;

    setState(() {
      item.isDone = done;
    });

    final lifestyleId = _lifestyleId;
    if (lifestyleId == null) return;

    await _questController.savePracticedStateToLocal(lifestyleId, _questItems);
    final result = await _questController.savePracticedStateToServer(
      lifestyleId,
      _questItems,
      toggledItem: item,
    );
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        item.isDone = !done;
      });
      final message =
          (result['message'] ?? '생활습관 저장에 실패했습니다.').toString();
      showErrorSnackBar(context, message);
    }
  }

  /// 상세 다이얼로그 안에서 삭제 확인 후 호출 (별도 확인 팝업 없음)
  Future<void> _removeCommittedHabitFromDialog(
    HomeQuestItem item,
    BuildContext editorContext,
  ) async {
    final id = item.committedActionId;
    if (id == null) return;

    final result = await _questController.retireCommittedAction(id);
    if (!mounted) return;

    if (result['success'] == true) {
      final lifestyleId = _lifestyleId;
      setState(() {
        _questItems.removeWhere((e) => e.id == item.id);
      });
      if (lifestyleId != null) {
        await _questController.savePracticedStateToLocal(
          lifestyleId,
          _questItems,
        );
      }
      if (editorContext.mounted) {
        Navigator.of(editorContext).pop();
      }
      if (!mounted) return;
    } else {
      final message = (result['message'] ?? '삭제에 실패했습니다.').toString();
      showErrorSnackBar(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedded) {
      return const MainTabShell(initialTab: AppNavTab.home);
    }
    final isVisible = HomeVisibilityHelper.isHomeScreenVisible(context);

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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      AppBottomNavBar.height,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 24),
                            SlideTransition(
                              position: _engineSlide,
                              child: FadeTransition(
                                opacity: _engineOpacity,
                                child: _buildEngineLabel(),
                              ),
                            ),
                            const SizedBox(height: 28),
                            SlideTransition(
                              position: _simulationSlide,
                              child: FadeTransition(
                                opacity: _simulationOpacity,
                                child: _buildSimulationSection(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SlideTransition(
                              position: _recentSlide,
                              child: FadeTransition(
                                opacity: _recentOpacity,
                                child: _buildRecentPredictionSection(context),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SlideTransition(
                              position: _questSlide,
                              child: FadeTransition(
                                opacity: _questOpacity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildQuestSection(context),
                                    const SizedBox(height: 16),
                                    HomeHabitDistributionSection(
                                      questItems: _questItems,
                                      isLoading: _isLoadingQuests,
                                      hasError: _questError != null,
                                      primaryColor: _primary,
                                      gameCardColor: _gameCard,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
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

  Widget _buildEngineLabel() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'BioStream Engine',
          style: TextStyle(
            color: _primary.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.6,
          ),
        ),
      ],
    );
  }

  Widget _buildSimulationSection(BuildContext context) {
    return HomeSimulationSection(
      primaryColor: _primary,
      backgroundDarkColor: _backgroundDark,
      onStartScan: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FaceScanScreen()),
        );
      },
    );
  }

  Widget _buildQuestSection(BuildContext context) {
    return HomeQuestSection(
      primaryColor: _primary,
      gameCardColor: _gameCard,
      isLoadingQuests: _isLoadingQuests,
      questError: _questError,
      questItems: _questItems,
      onOpenQuestEditor: _showQuestEditorDialog,
      onToggleDoneOnList: _setQuestItemDone,
      onGoToReport: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FaceScanScreen()),
        );
      },
    );
  }

  Widget _buildRecentPredictionSection(BuildContext context) {
    return HomeRecentPredictionSection(
      originalImageUrl: _originalImageUrl,
      generatedImageUrl: _generatedImageUrl,
      predictionPoint: _predictionPoint,
      summaryData: _reportSummaryData,
      primaryColor: _primary,
      gameCardColor: _gameCard,
      onOpenResult: () {
        final id = _lifestyleId;
        if (id == null) {
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ResultScreen(viewOnlyLifestyleId: id),
          ),
        );
      },
    );
  }

  void _showQuestEditorDialog(HomeQuestItem item) {
    showHomeQuestDetailDialog(
      context: context,
      item: item,
      accentColor: _primary,
      onConfirmRemoveCommitted: _removeCommittedHabitFromDialog,
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AppBottomNavBar(activeTab: AppNavTab.home),
    );
  }
}
