import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../services/lifestyle_service.dart';
import 'result_screen_controller.dart';
import 'result_screen_helper.dart';
import 'result_screen_view_data.dart';
import '../coach/coach_chat_screen.dart';
import '../home_screen.dart';
import '../login_screen.dart';
import '../../widgets/result/result_action_buttons.dart';
import '../../widgets/result/result_aging_simulation_section.dart';
import '../../widgets/result/result_async_state_view.dart';
import '../../widgets/result/result_critical_factors_section.dart';
import '../../widgets/result/result_health_report_section.dart';
import '../../widgets/result/result_network_image.dart';
import '../../widgets/result/result_report_content.dart';
import '../../widgets/result/result_screen_header.dart';

class ResultScreen extends StatefulWidget {
  final String? situationText;
  final String? originalImageUrl;

  const ResultScreen({super.key, this.situationText, this.originalImageUrl});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final LifestyleService _lifestyleService = LifestyleService();
  late final ResultScreenController _controller;
  Map<String, dynamic>? _lifestyleData;
  Map<String, dynamic>? _reportData; // 새로운 스키마: {tabs, sections}
  String? _originalImageUrl;
  String? _generatedImageUrl;
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  String? _errorMessage;
  String? _selectedTab; // 선택된 탭
  String? _selectedLifestyleSubTab; // lifestyle 서브탭 (smoking, drinking, stress)
  bool _isSavingComparison = false;

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  bool get _hasNotionButton => _reportData?['notion_url'] != null;

  void _onShare() {
    // TODO: Share functionality
    debugPrint('Share tapped');
  }

  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _onLifestyleSubTabChanged(String subKey) {
    setState(() {
      _selectedLifestyleSubTab = subKey;
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = ResultScreenController(
      lifestyleService: _lifestyleService,
      situationText: widget.situationText,
    );
    if (widget.originalImageUrl != null &&
        widget.originalImageUrl!.isNotEmpty) {
      ResultScreenHelper.resolveImageUrl(widget.originalImageUrl)
          .then((resolved) {
        if (!mounted || resolved == null || resolved.isEmpty) return;
        setState(() {
          _originalImageUrl = resolved;
        });
      });
    }
    _loadDataAndGenerateReport();
  }

  Future<void> _loadDataAndGenerateReport() async {
    setState(() {
      _isLoading = true;
      _isGeneratingReport = false;
      _errorMessage = null;
    });

    final loadResult = await _controller.loadLifestyleData();
    if (!mounted) return;

    if (!loadResult.success || loadResult.lifestyleData == null) {
      setState(() {
        _errorMessage = loadResult.errorMessage ?? '데이터를 불러올 수 없습니다.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _lifestyleData = loadResult.lifestyleData;
      _originalImageUrl = loadResult.originalImageUrl ?? _originalImageUrl;
      _generatedImageUrl = loadResult.generatedImageUrl ?? _generatedImageUrl;
      _isLoading = false;
      _isGeneratingReport = true;
    });

    await _generateHealthReport();
  }

  Future<void> _generateHealthReport({bool force = false}) async {
    final generateResult = await _controller.generateHealthReport(
      lifestyleData: _lifestyleData,
      currentLifestyleData: _lifestyleData,
      showRegenerateDialog: _showRegenerateDialog,
      force: force,
    );
    if (!mounted) return;

    if (generateResult.tokenExpired) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    if (!generateResult.success || generateResult.reportData == null) {
      setState(() {
        _errorMessage = generateResult.errorMessage ?? '건강 리포트를 생성할 수 없습니다.';
        _isGeneratingReport = false;
      });
      if (_errorMessage != null &&
          (_errorMessage!.contains('설문조사 데이터를 찾을 수 없습니다') ||
              _errorMessage!.contains('설문조사 데이터를 불러올 수 없습니다'))) {
        _showSnack(_errorMessage!);
      }
      return;
    }

    setState(() {
      _lifestyleData = generateResult.lifestyleData ?? _lifestyleData;
      _reportData = generateResult.reportData;
      _originalImageUrl = generateResult.originalImageUrl ?? _originalImageUrl;
      _generatedImageUrl =
          generateResult.generatedImageUrl ?? _generatedImageUrl;
      _selectedTab = generateResult.selectedTab ?? _selectedTab;
      _isGeneratingReport = false;
      _errorMessage = null;
    });
  }

  Future<bool?> _showRegenerateDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2C16),
          title: const Text(
            '리포트 재생성',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            '이미 생성된 리포트가 있습니다.\n재생성 하시겠습니까?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // 아니오
              child: const Text(
                '아니오',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // 예
              child: const Text(
                '예',
                style: TextStyle(color: Color(0xFF37EC13)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 16);
    final viewData = ResultScreenViewData.fromLifestyleData(_lifestyleData);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            ResultScreenHeader(
              isDark: isDark,
              horizontalPadding: horizontalPadding,
              showNotionButton: _hasNotionButton,
              onBack: () => Navigator.of(context).pop(),
              onHome: _goHome,
              onOpenNotion: _openNotionPage,
              onShare: _onShare,
            ),

            // Main Content
            Expanded(
              child: ResultAsyncStateView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                isDark: isDark,
                onRetry: _loadDataAndGenerateReport,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      SizedBox(height: Responsive.padding(context, 8)),

                      ResultAgingSimulationSection(
                        isDark: isDark,
                        currentAgeLabel: viewData.currentAgeText,
                        targetAgeLabel: viewData.targetAgeText,
                        originalImageUrl: _originalImageUrl,
                        generatedImageUrl: _generatedImageUrl,
                        managedSkinAge: viewData.managedSkinAge,
                        unmanagedSkinAge: viewData.unmanagedSkinAge,
                        visualGap: viewData.visualGap,
                        potentialPercentage: viewData.potentialPercentage,
                        imageBuilder: (imageUrl) =>
                            ResultNetworkImage(imageUrl: imageUrl),
                      ),

                      // Health Report Section (새로운 탭 + 4카드 구조)
                      if (_reportData != null || _isGeneratingReport)
                        ResultHealthReportSection(
                          isDark: isDark,
                          isGenerating: _isGeneratingReport,
                          reportContent:
                              (_reportData != null && _selectedTab != null)
                                  ? ResultReportContent(
                                      reportData: _reportData,
                                      selectedTab: _selectedTab,
                                      onTabSelected: _onTabSelected,
                                      selectedLifestyleSubTab:
                                          _selectedLifestyleSubTab,
                                      onLifestyleSubTabChanged:
                                          _onLifestyleSubTabChanged,
                                      isDark: isDark,
                                    )
                                  : null,
                        ),

                      // Critical Factors Section
                      ResultCriticalFactorsSection(
                        isDark: isDark,
                        collagenLabel: viewData.collagenLabel,
                        collagenScore: viewData.collagenScore,
                        collagenColor: viewData.collagenColor,
                        uvLabel: viewData.uvLabel,
                        uvScore: viewData.uvScore,
                        uvColor: viewData.uvColor,
                      ),

                      SizedBox(height: Responsive.padding(context, 24)),

                      // Action Buttons
                      ResultActionButtons(
                        isDark: isDark,
                        showNotionButton: _hasNotionButton,
                        isSavingComparison: _isSavingComparison,
                        onViewActionPlan: _openActionPlan,
                        onOpenNotion: _openNotionPage,
                        onSaveComparison: _saveComparisonToGallery,
                      ),

                      SizedBox(height: Responsive.padding(context, 24)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveComparisonToGallery() async {
    if (_isSavingComparison) return;
    setState(() => _isSavingComparison = true);
    final result = await _controller.saveComparison(
      lifestyleId: _lifestyleData?['lifestyle_id'] as int?,
      reportData: _reportData,
      generatedImageUrl: _generatedImageUrl,
    );
    if (!mounted) return;
    _showSnack(result.message);
    setState(() => _isSavingComparison = false);
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _openActionPlan() {
    final rid = _lifestyleData?['lifestyle_id'] as int?;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(
        builder: (context) => CoachChatScreen(reportId: rid)));
  }

  Future<void> _openNotionPage() async {
    final notionUrl = _reportData?['notion_url'];
    if (notionUrl == null || notionUrl.toString().trim().isEmpty) {
      _showSnack('링크를 열 수 없습니다');
      return;
    }
    final opened = await ResultScreenHelper.openExternalUrl(
      notionUrl.toString(),
    );
    if (!opened) {
      _showSnack('링크를 열 수 없습니다');
    }
  }
}
