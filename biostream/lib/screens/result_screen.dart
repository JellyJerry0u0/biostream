import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/lifestyle_service.dart';
import 'coach_chat_screen.dart';
import '../widgets/report_tabs_bar.dart';
import '../widgets/report_cards/problem_card.dart';
import '../widgets/report_cards/cause_card.dart';
import '../widgets/report_cards/action_card.dart';
import '../widgets/report_cards/simulation_card.dart';
import '../widgets/evidence_modal.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final LifestyleService _lifestyleService = LifestyleService();
  Map<String, dynamic>? _lifestyleData;
  Map<String, dynamic>? _reportData; // 새로운 스키마: {tabs, sections}
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  String? _errorMessage;
  String? _selectedTab; // 선택된 탭
  String? _selectedLifestyleSubTab; // lifestyle 서브탭 (smoking, drinking, stress)

  @override
  void initState() {
    super.initState();
    _loadDataAndGenerateReport();
  }

  Future<void> _loadDataAndGenerateReport() async {
    setState(() {
      _isLoading = true;
      _isGeneratingReport = false;
      _errorMessage = null;
    });

    try {
      // 1. Lifestyle 데이터 로드
      final lifestyleResult = await _lifestyleService.getLifestyleData();
      debugPrint('🔍 Lifestyle 데이터 로드 결과: $lifestyleResult');

      if (lifestyleResult['success'] == true &&
          lifestyleResult['data'] != null) {
        debugPrint('✅ 데이터 로드 성공: ${lifestyleResult['data']}');
        setState(() {
          _lifestyleData = lifestyleResult['data'];
          _isLoading = false;
          _isGeneratingReport = true; // 리포트 생성 시작
        });

        // 2. LLM을 사용하여 건강 리포트 생성
        await _generateHealthReport();
      } else {
        debugPrint('❌ 데이터 로드 실패: ${lifestyleResult['message']}');
        setState(() {
          _errorMessage = lifestyleResult['message'] ?? '데이터를 불러올 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 에러 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      setState(() {
        _errorMessage = '데이터 로드 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateHealthReport({bool force = false}) async {
    try {
      debugPrint('🤖 건강 리포트 생성 시작... force: $force');

      // lifestyle_id 가져오기
      int? lifestyleId;
      if (_lifestyleData != null) {
        // getLifestyleData API가 반환하는 lifestyle_id 사용
        if (_lifestyleData!['lifestyle_id'] != null) {
          lifestyleId = _lifestyleData!['lifestyle_id'] as int;
          debugPrint('✅ lifestyle_id 확인: $lifestyleId');
        } else {
          debugPrint('⚠️ lifestyle_id가 없습니다. _lifestyleData: $_lifestyleData');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('설문조사 데이터를 찾을 수 없습니다. 먼저 설문조사를 완료해주세요.')),
          );
          return;
        }
      } else {
        debugPrint('❌ _lifestyleData가 null입니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설문조사 데이터를 불러올 수 없습니다.')),
        );
        return;
      }

      final result = await _lifestyleService.generateHealthReport(lifestyleId,
          force: force);

      if (result['success'] == true) {
        // 이미 리포트가 있는 경우 다이얼로그 표시
        if (result['already_exists'] == true && !force) {
          debugPrint('⚠️ 이미 생성된 리포트가 있습니다. 사용자 확인 대기...');
          final shouldRegenerate = await _showRegenerateDialog();

          if (shouldRegenerate == true) {
            // 재생성 선택 시 force=true로 다시 호출
            await _generateHealthReport(force: true);
            return;
          } else {
            // 기존 리포트 표시
            debugPrint('✅ 기존 리포트를 표시합니다.');
          }
        }

        if (result['report'] != null) {
          debugPrint('✅ 건강 리포트 생성/조회 성공');
          final reportData = result['report'] as Map<String, dynamic>;

          // 새로운 스키마 처리: tabs + sections 구조
          Map<String, dynamic>? reportDataNew;
          if (reportData.containsKey('tabs') &&
              reportData.containsKey('sections')) {
            reportDataNew = reportData;
          } else {
            // 기존 스키마 호환: cards 배열을 새 스키마로 변환
            debugPrint('⚠️ 기존 스키마 감지, 변환 중...');
            reportDataNew = _convertOldSchemaToNew(reportData, result['cards']);
          }

          setState(() {
            _reportData = reportDataNew;
            // 첫 번째 탭 선택
            if (reportDataNew != null && reportDataNew['tabs'] != null) {
              final tabs = reportDataNew['tabs'] as List<dynamic>;
              if (tabs.isNotEmpty) {
                _selectedTab = tabs[0] as String;
              }
            }
            _isGeneratingReport = false;
          });
        } else {
          debugPrint('❌ 리포트 데이터가 없습니다.');
          setState(() {
            _errorMessage = result['message'] ?? '건강 리포트를 생성할 수 없습니다.';
            _isGeneratingReport = false;
          });
        }
      } else {
        debugPrint('❌ 건강 리포트 생성 실패: ${result['message']}');

        // 토큰 만료인 경우 로그인 화면으로 이동
        if (result['token_expired'] == true) {
          // 토큰이 만료되었으므로 로그인 화면으로 이동
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
          return;
        }

        setState(() {
          _errorMessage = result['message'] ?? '건강 리포트를 생성할 수 없습니다.';
          _isGeneratingReport = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 리포트 생성 에러: $e');
      debugPrint('스택 트레이스: $stackTrace');
      setState(() {
        _errorMessage = '건강 리포트 생성 중 오류가 발생했습니다: $e';
        _isGeneratingReport = false;
      });
    }
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

  // 기존 스키마를 새 스키마로 변환 (호환성)
  Map<String, dynamic> _convertOldSchemaToNew(
    Map<String, dynamic> reportData,
    dynamic cards,
  ) {
    final sections = <String, dynamic>{};
    final tabs = <String>[];

    if (cards != null && cards is List) {
      final sectionTitles = {
        'goals': {'title': '주요 목표 분석 및 개선 방안', 'key': 'goals'},
        'sleep': {'title': '수면 및 리듬', 'key': 'sleep'},
        'uv': {'title': '자외선 및 노화 관리', 'key': 'uv'},
        'lifestyle': {'title': '생활습관 관리', 'key': 'lifestyle'},
        'activity': {'title': '활동 및 대사', 'key': 'activity'},
      };

      int index = 0;
      for (final card in cards) {
        final cardMap = card as Map<String, dynamic>;
        final sectionKeys = sectionTitles.keys.toList();
        final sectionKey = index < sectionKeys.length
            ? sectionKeys[index % sectionKeys.length]
            : 'goals';
        final sectionInfo = sectionTitles[sectionKey]!;

        if (!sections.containsKey(sectionKey)) {
          sections[sectionKey] = {
            'title': sectionInfo['title'],
            'cards': [],
            'evidence_refs': {'narrative': [], 'quant': []},
          };
          tabs.add(sectionKey);
        }

        // 기존 카드를 새 형식으로 변환 (간단한 fallback)
        sections[sectionKey]['cards'].add({
          'type': 'problem',
          'title': '현재 상태',
          'text': cardMap['content'] ?? '',
        });
        index++;
      }
    }

    return {
      'tabs': tabs,
      'sections': sections,
    };
  }

  Widget _buildReportSection(BuildContext context, bool isDark) {
    final tabs = _reportData!['tabs'] as List<dynamic>? ?? [];
    final sections = _reportData!['sections'] as Map<String, dynamic>? ?? {};

    if (tabs.isEmpty || _selectedTab == null) {
      return _buildErrorSection('리포트 데이터가 없습니다.');
    }

    return Column(
      children: [
        // 탭 바
        ReportTabsBar(
          tabs: tabs.cast<String>(),
          selectedTab: _selectedTab!,
          onTabSelected: (tab) {
            setState(() {
              _selectedTab = tab;
            });
          },
        ),

        SizedBox(height: Responsive.padding(context, 16)),

        // 선택된 섹션 표시
        if (sections.containsKey(_selectedTab))
          _buildSectionView(
              context, isDark, sections[_selectedTab] as Map<String, dynamic>)
        else
          _buildErrorSection('섹션 데이터를 찾을 수 없습니다.'),
      ],
    );
  }

  Widget _buildSectionView(
      BuildContext context, bool isDark, Map<String, dynamic> sectionData) {
    final title = sectionData['title'] as String? ?? '';
    final cards = sectionData['cards'] as List<dynamic>?;
    final subsections = sectionData['subsections'] as List<dynamic>?;
    final evidenceRefs =
        sectionData['evidence_refs'] as Map<String, dynamic>? ?? {};

    // 하위 섹션이 있으면 서브탭 형태로 렌더링 (lifestyle 섹션)
    if (subsections != null && subsections.isNotEmpty) {
      // 현재 선택된 서브탭 결정 (없으면 첫 번째)
      final selectedSubKey = _selectedLifestyleSubTab ??
          (subsections[0] as Map<String, dynamic>)['key'] as String? ??
          '';

      // 선택된 서브탭의 데이터 찾기
      Map<String, dynamic>? activeSubsection;
      for (final sub in subsections) {
        if ((sub as Map<String, dynamic>)['key'] == selectedSubKey) {
          activeSubsection = sub;
          break;
        }
      }
      activeSubsection ??= subsections[0] as Map<String, dynamic>;
      final activeCards = activeSubsection['cards'] as List<dynamic>? ?? [];
      final displayCards = _ensureFourCards(activeCards);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더 + 근거 보기 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) =>
                        EvidenceModal(evidenceRefs: evidenceRefs),
                  );
                },
                icon: Icon(
                  Icons.info_outline,
                  size: Responsive.iconSize(context, 18),
                  color: const Color(0xFF37EC13),
                ),
                label: Text(
                  '근거 보기',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    color: const Color(0xFF37EC13),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: Responsive.padding(context, 12)),

          // 서브탭 바
          Container(
            height: Responsive.fontSize(context, 42),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: subsections.map((sub) {
                final subMap = sub as Map<String, dynamic>;
                final subKey = subMap['key'] as String? ?? '';
                final subTitle = subMap['title'] as String? ?? subKey;
                final isActive = subKey == selectedSubKey;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLifestyleSubTab = subKey;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF37EC13)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF37EC13)
                                      .withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          subTitle,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 13),
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isActive
                                ? const Color(0xFF101B0D)
                                : (isDark
                                    ? Colors.white60
                                    : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: Responsive.padding(context, 16)),

          // 선택된 서브탭의 카드들 렌더링
          ...displayCards.map((card) {
            final cardType = card['type'] as String? ?? '';

            switch (cardType) {
              case 'problem':
                return ProblemCard(text: card['text'] ?? '');
              case 'cause':
                return CauseCard(text: card['text'] ?? '');
              case 'action':
                final items = card['items'] as List<dynamic>? ?? [];
                return ActionCard(
                  items: items
                      .map((item) => item as Map<String, dynamic>)
                      .toList(),
                );
              case 'simulation':
                return SimulationCard(
                  text: card['text'] ?? '',
                  meta: card['meta'] as Map<String, dynamic>?,
                );
              default:
                return Container();
            }
          }).toList(),
        ],
      );
    }

    // 일반 섹션 (하위 섹션 없음)
    final displayCards = _ensureFourCards(cards ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더 + 근거 보기 버튼
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 20),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) =>
                      EvidenceModal(evidenceRefs: evidenceRefs),
                );
              },
              icon: Icon(
                Icons.info_outline,
                size: Responsive.iconSize(context, 18),
                color: const Color(0xFF37EC13),
              ),
              label: Text(
                '근거 보기',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  color: const Color(0xFF37EC13),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: Responsive.padding(context, 16)),

        // 4개 카드 렌더링
        ...displayCards.map((card) {
          final cardType = card['type'] as String? ?? '';

          switch (cardType) {
            case 'problem':
              return ProblemCard(text: card['text'] ?? '');
            case 'cause':
              return CauseCard(text: card['text'] ?? '');
            case 'action':
              final items = card['items'] as List<dynamic>? ?? [];
              return ActionCard(
                items:
                    items.map((item) => item as Map<String, dynamic>).toList(),
              );
            case 'simulation':
              return SimulationCard(
                text: card['text'] ?? '',
                meta: card['meta'] as Map<String, dynamic>?,
              );
            default:
              return Container(); // 빈 위젯
          }
        }).toList(),
      ],
    );
  }

  List<Map<String, dynamic>> _ensureFourCards(List<dynamic> cards) {
    final result = <Map<String, dynamic>>[];

    // 기존 카드 추가
    for (final card in cards) {
      if (card is Map<String, dynamic>) {
        result.add(card);
      }
    }

    // 부족한 카드를 fallback으로 채움
    final cardTypes = ['problem', 'cause', 'action', 'simulation'];
    while (result.length < 4) {
      final index = result.length;
      result.add({
        'type': cardTypes[index],
        'title': _getCardTitle(cardTypes[index]),
        'text': '데이터 생성 실패',
        if (cardTypes[index] == 'action')
          'items': [
            {'title': '행동 1', 'detail': '데이터 생성 실패'},
            {'title': '행동 2', 'detail': '데이터 생성 실패'},
            {'title': '행동 3', 'detail': '데이터 생성 실패'},
          ],
        if (cardTypes[index] == 'simulation') 'meta': {'mode': 'estimated'},
      });
    }

    // 정확히 4개만 반환
    return result.take(4).toList();
  }

  String _getCardTitle(String type) {
    switch (type) {
      case 'problem':
        return '현재 상태';
      case 'cause':
        return '왜 이런 상태인가';
      case 'action':
        return '당신에게 필요한 행동 3가지';
      case 'simulation':
        return '예상 경로';
      default:
        return '';
    }
  }

  Widget _buildErrorSection(String message) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.red[700]),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalPadding = Responsive.padding(context, 16);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(horizontalPadding),
              decoration: BoxDecoration(
                color:
                    (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
                        .withOpacity(0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: Responsive.fontSize(context, 40),
                        height: Responsive.fontSize(context, 40),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back,
                          size: Responsive.iconSize(context, 24),
                          color:
                              isDark ? Colors.white : const Color(0xFF101B0D),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Results',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 16),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark
                          ? Colors.white.withOpacity(0.9)
                          : const Color(0xFF101B0D),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // TODO: Share functionality
                        debugPrint('Share tapped');
                      },
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        width: Responsive.fontSize(context, 40),
                        height: Responsive.fontSize(context, 40),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.2)
                              : Colors.white.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.share,
                          size: Responsive.iconSize(context, 24),
                          color:
                              isDark ? Colors.white : const Color(0xFF101B0D),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF37EC13),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: Responsive.iconSize(context, 48),
                                color: Colors.red,
                              ),
                              SizedBox(height: Responsive.padding(context, 16)),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 16),
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF101B0D),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: Responsive.padding(context, 16)),
                              ElevatedButton(
                                onPressed: _loadDataAndGenerateReport,
                                child: Text('다시 시도'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding),
                          child: Column(
                            children: [
                              SizedBox(height: Responsive.padding(context, 8)),

                              // Title
                              Text(
                                'Aging Simulation',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 24),
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF101B0D),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(height: Responsive.padding(context, 24)),

                              // Age Comparison
                              Row(
                                children: [
                                  // Current Age
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Container(
                                          width:
                                              Responsive.fontSize(context, 80),
                                          height:
                                              Responsive.fontSize(context, 80),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(19.2),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white
                                                      .withOpacity(0.1)
                                                  : Colors.white,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Icon(
                                                  Icons.face_3,
                                                  size: Responsive.iconSize(
                                                      context, 32),
                                                  color: isDark
                                                      ? Colors.grey[500]
                                                      : Colors.grey[400],
                                                ),
                                              ),
                                              Positioned.fill(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topRight,
                                                      end: Alignment.bottomLeft,
                                                      colors: [
                                                        Colors.black
                                                            .withOpacity(0.1),
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                            height:
                                                Responsive.padding(context, 8)),
                                        Text(
                                          _lifestyleData?['profile']?['age'] !=
                                                  null
                                              ? 'Now (${_lifestyleData!['profile']['age'].toString().split(' ')[0]})'
                                              : 'Now',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                                context, 10),
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              height: 2,
                                              margin: EdgeInsets.symmetric(
                                                horizontal: Responsive.padding(
                                                    context, 16),
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white
                                                        .withOpacity(0.2)
                                                    : Colors.grey[300],
                                                border: Border(
                                                  top: BorderSide(
                                                    color: isDark
                                                        ? Colors.white
                                                            .withOpacity(0.2)
                                                        : Colors.grey[300]!,
                                                    width: 2,
                                                    style: BorderStyle.solid,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: Responsive.padding(
                                                    context, 12),
                                                vertical: Responsive.padding(
                                                    context, 4),
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF132210)
                                                    : const Color(0xFFF6F8F6),
                                              ),
                                              child: Icon(
                                                Icons.double_arrow,
                                                size: Responsive.iconSize(
                                                    context, 18),
                                                color: isDark
                                                    ? Colors.grey[500]
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Target Age
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Container(
                                          width:
                                              Responsive.fontSize(context, 80),
                                          height:
                                              Responsive.fontSize(context, 80),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: isDark
                                                  ? [
                                                      Colors.white,
                                                      Colors.grey[200]!
                                                    ]
                                                  : [
                                                      const Color(0xFF101B0D),
                                                      const Color(0xFF1F3519)
                                                    ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(19.2),
                                            border: Border.all(
                                              color: const Color(0xFF37EC13),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF37EC13)
                                                    .withOpacity(0.3),
                                                blurRadius: 20,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Text(
                                                  _getTargetAge(),
                                                  style: TextStyle(
                                                    fontSize:
                                                        Responsive.fontSize(
                                                            context, 28),
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF101B0D)
                                                        : Colors.white,
                                                  ),
                                                ),
                                              ),
                                              Positioned.fill(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF37EC13)
                                                            .withOpacity(0.1),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                            height:
                                                Responsive.padding(context, 8)),
                                        Text(
                                          'Target Age',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                                context, 10),
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF37EC13),
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: Responsive.padding(context, 8)),

                              // Comparison Images
                              SizedBox(
                                height: Responsive.fontSize(context, 416),
                                child: Stack(
                                  children: [
                                    Row(
                                      children: [
                                        // Left Image - Managed
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(32),
                                                bottomLeft: Radius.circular(32),
                                              ),
                                              border: Border.all(
                                                color: const Color(0xFF37EC13)
                                                    .withOpacity(0.5),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF37EC13)
                                                      .withOpacity(0.15),
                                                  blurRadius: 20,
                                                  spreadRadius: 0,
                                                ),
                                              ],
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Stack(
                                              children: [
                                                // Background Image - Original Image
                                                Positioned.fill(
                                                  child: _buildImageWidget(
                                                    _lifestyleData?['images']
                                                        ?['original_image_url'],
                                                  ),
                                                ),
                                                // Gradient Overlay
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.black
                                                              .withOpacity(0.1),
                                                          Colors.transparent,
                                                          Colors.black
                                                              .withOpacity(0.9),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Badge
                                                Positioned(
                                                  top: Responsive.padding(
                                                      context, 12),
                                                  left: Responsive.padding(
                                                      context, 12),
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal:
                                                          Responsive.padding(
                                                              context, 8),
                                                      vertical:
                                                          Responsive.padding(
                                                              context, 4),
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF37EC13),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              9999),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.check_circle,
                                                          size: Responsive
                                                              .iconSize(
                                                                  context, 12),
                                                          color: const Color(
                                                              0xFF101B0D),
                                                        ),
                                                        SizedBox(
                                                            width: Responsive
                                                                .padding(
                                                                    context,
                                                                    4)),
                                                        Text(
                                                          'Managed O',
                                                          style: TextStyle(
                                                            fontSize: Responsive
                                                                .fontSize(
                                                                    context,
                                                                    10),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: const Color(
                                                                0xFF101B0D),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                // Bottom Text
                                                Positioned(
                                                  bottom: Responsive.padding(
                                                      context, 20),
                                                  left: Responsive.padding(
                                                      context, 16),
                                                  right: Responsive.padding(
                                                      context, 8),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Youthful',
                                                        style: TextStyle(
                                                          fontSize: Responsive
                                                              .fontSize(
                                                                  context, 20),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                          height: 1.0,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                          height: Responsive
                                                              .padding(
                                                                  context, 4)),
                                                      Text(
                                                        'Skin Age: ${_calculateManagedSkinAge(_getCurrentAge(), _getTargetYears())}',
                                                        style: TextStyle(
                                                          fontSize: Responsive
                                                              .fontSize(
                                                                  context, 10),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: const Color(
                                                              0xFF37EC13),
                                                          letterSpacing: 2.0,
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Right Image - Not Managed
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topRight: Radius.circular(32),
                                                bottomRight:
                                                    Radius.circular(32),
                                              ),
                                              border: Border.all(
                                                color:
                                                    Colors.red.withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: Stack(
                                              children: [
                                                // Background Image - Generated Image
                                                Positioned.fill(
                                                  child: ColorFiltered(
                                                    colorFilter:
                                                        ColorFilter.mode(
                                                      const Color(0xFF8B6914)
                                                          .withOpacity(0.2),
                                                      BlendMode.overlay,
                                                    ),
                                                    child: _buildImageWidget(
                                                      _lifestyleData?['images']
                                                          ?[
                                                          'generated_image_url'],
                                                    ),
                                                  ),
                                                ),
                                                // Gradient Overlay
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.black
                                                              .withOpacity(0.9),
                                                          Colors.black
                                                              .withOpacity(0.1),
                                                          Colors.transparent,
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Badge
                                                Positioned(
                                                  top: Responsive.padding(
                                                      context, 12),
                                                  right: Responsive.padding(
                                                      context, 12),
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal:
                                                          Responsive.padding(
                                                              context, 8),
                                                      vertical:
                                                          Responsive.padding(
                                                              context, 4),
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red[600],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              9999),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.2),
                                                          blurRadius: 4,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.close,
                                                          size: Responsive
                                                              .iconSize(
                                                                  context, 12),
                                                          color: Colors.white,
                                                        ),
                                                        SizedBox(
                                                            width: Responsive
                                                                .padding(
                                                                    context,
                                                                    4)),
                                                        Text(
                                                          'Managed X',
                                                          style: TextStyle(
                                                            fontSize: Responsive
                                                                .fontSize(
                                                                    context,
                                                                    10),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                // Bottom Text
                                                Positioned(
                                                  bottom: Responsive.padding(
                                                      context, 20),
                                                  left: Responsive.padding(
                                                      context, 16),
                                                  right: Responsive.padding(
                                                      context, 16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Aged',
                                                        style: TextStyle(
                                                          fontSize: Responsive
                                                              .fontSize(
                                                                  context, 20),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                          height: 1.0,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                          height: Responsive
                                                              .padding(
                                                                  context, 4)),
                                                      Text(
                                                        'Skin Age: ${_calculateUnmanagedSkinAge(_getCurrentAge(), _getTargetYears())}',
                                                        style: TextStyle(
                                                          fontSize: Responsive
                                                              .fontSize(
                                                                  context, 10),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              Colors.red[400],
                                                          letterSpacing: 2.0,
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // VS Badge
                                    Positioned(
                                      top: 0,
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Container(
                                          padding: EdgeInsets.all(
                                              Responsive.padding(context, 8)),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF2A4025)
                                                : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.black
                                                      .withOpacity(0.2)
                                                  : Colors.grey[100]!,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.1),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'VS',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 10),
                                              fontWeight: FontWeight.w900,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.grey[800],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: Responsive.padding(context, 8)),

                              // Stats Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(
                                          Responsive.padding(context, 16)),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.red[900]!.withOpacity(0.1)
                                            : Colors.red[50],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.red[900]!
                                                  .withOpacity(0.3)
                                              : Colors.red[100]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.face_retouching_off,
                                                size: Responsive.iconSize(
                                                    context, 20),
                                                color: isDark
                                                    ? Colors.red[400]
                                                    : Colors.red[700],
                                              ),
                                              SizedBox(
                                                  width: Responsive.padding(
                                                      context, 8)),
                                              Text(
                                                'Visual Gap',
                                                style: TextStyle(
                                                  fontSize: Responsive.fontSize(
                                                      context, 10),
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.red[300]!
                                                          .withOpacity(0.7)
                                                      : Colors.red[600]!
                                                          .withOpacity(0.7),
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                              height: Responsive.padding(
                                                  context, 8)),
                                          Text(
                                            '${_getVisualGap()} Yrs',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 28),
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.red[100]
                                                  : Colors.red[900],
                                              height: 1.0,
                                            ),
                                          ),
                                          SizedBox(
                                              height: Responsive.padding(
                                                  context, 8)),
                                          Text(
                                            'Difference in apparent age',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 12),
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.red[400]
                                                  : Colors.red[600],
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                      width: Responsive.padding(context, 12)),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.all(
                                          Responsive.padding(context, 16)),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.green[900]!
                                                .withOpacity(0.1)
                                            : Colors.green[50],
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.green[900]!
                                                  .withOpacity(0.3)
                                              : Colors.green[100]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.water_drop,
                                                size: Responsive.iconSize(
                                                    context, 20),
                                                color: isDark
                                                    ? Colors.green[400]
                                                    : Colors.green[700],
                                              ),
                                              SizedBox(
                                                  width: Responsive.padding(
                                                      context, 8)),
                                              Text(
                                                'Potential',
                                                style: TextStyle(
                                                  fontSize: Responsive.fontSize(
                                                      context, 10),
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.green[300]!
                                                          .withOpacity(0.7)
                                                      : Colors.green[600]!
                                                          .withOpacity(0.7),
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                              height: Responsive.padding(
                                                  context, 8)),
                                          Text(
                                            '-${_getPotentialPercentage().toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 28),
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.green[100]
                                                  : Colors.green[900],
                                              height: 1.0,
                                            ),
                                          ),
                                          SizedBox(
                                              height: Responsive.padding(
                                                  context, 8)),
                                          Text(
                                            'Less wrinkles with care',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 12),
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.green[400]
                                                  : Colors.green[700],
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: Responsive.padding(context, 16)),

                              // Health Report Section (새로운 탭 + 4카드 구조)
                              if (_reportData != null || _isGeneratingReport)
                                Container(
                                  margin: EdgeInsets.only(
                                      bottom: Responsive.padding(context, 16)),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 헤더
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.medical_services,
                                            size: Responsive.iconSize(
                                                context, 24),
                                            color: const Color(0xFF37EC13),
                                          ),
                                          SizedBox(
                                              width: Responsive.padding(
                                                  context, 8)),
                                          Text(
                                            'AI 건강 리포트',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 18),
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                          height:
                                              Responsive.padding(context, 16)),

                                      // 로딩 상태
                                      if (_isGeneratingReport)
                                        Center(
                                          child: Column(
                                            children: [
                                              CircularProgressIndicator(
                                                color: const Color(0xFF37EC13),
                                              ),
                                              SizedBox(
                                                  height: Responsive.padding(
                                                      context, 16)),
                                              Text(
                                                'AI가 건강 리포트를 생성하고 있습니다...',
                                                style: TextStyle(
                                                  fontSize: Responsive.fontSize(
                                                      context, 14),
                                                  color: isDark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      // 리포트 데이터가 있을 때
                                      else if (_reportData != null &&
                                          _selectedTab != null)
                                        _buildReportSection(context, isDark),
                                    ],
                                  ),
                                ),

                              // Critical Factors Section
                              Container(
                                padding: EdgeInsets.all(
                                    Responsive.padding(context, 20)),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1A2C17)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey[100]!,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Critical Factors',
                                          style: TextStyle(
                                            fontSize: Responsive.fontSize(
                                                context, 18),
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal:
                                                Responsive.padding(context, 8),
                                            vertical:
                                                Responsive.padding(context, 4),
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withOpacity(0.1)
                                                : Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Impact Score',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 10),
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                        height:
                                            Responsive.padding(context, 16)),
                                    // Collagen Preservation
                                    Builder(
                                      builder: (context) {
                                        final collagenImpact =
                                            _getCollagenPreservationImpact();
                                        final impactColor = _getImpactColor(
                                            collagenImpact['level']);
                                        final impactScore =
                                            collagenImpact['score'] as double;

                                        return Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Collagen Preservation',
                                                  style: TextStyle(
                                                    fontSize:
                                                        Responsive.fontSize(
                                                            context, 14),
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark
                                                        ? Colors.grey[300]
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                                Text(
                                                  collagenImpact['label'],
                                                  style: TextStyle(
                                                    fontSize:
                                                        Responsive.fontSize(
                                                            context, 14),
                                                    fontWeight: FontWeight.bold,
                                                    color: impactColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                                height: Responsive.padding(
                                                    context, 6)),
                                            Container(
                                              height: Responsive.fontSize(
                                                  context, 8),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white
                                                        .withOpacity(0.1)
                                                    : Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(9999),
                                              ),
                                              child: Stack(
                                                children: [
                                                  Container(
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              9999),
                                                    ),
                                                  ),
                                                  FractionallySizedBox(
                                                    widthFactor: impactScore
                                                        .clamp(0.0, 1.0),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: impactColor,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(9999),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: impactColor
                                                                .withOpacity(
                                                                    0.5),
                                                            blurRadius: 10,
                                                            spreadRadius: 0,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    SizedBox(
                                        height:
                                            Responsive.padding(context, 16)),
                                    // UV Damage Control
                                    Builder(
                                      builder: (context) {
                                        final uvImpact =
                                            _getUVDamageControlImpact();
                                        final impactColor =
                                            _getImpactColor(uvImpact['level']);
                                        final impactScore =
                                            uvImpact['score'] as double;

                                        return Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'UV Damage Control',
                                                  style: TextStyle(
                                                    fontSize:
                                                        Responsive.fontSize(
                                                            context, 14),
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark
                                                        ? Colors.grey[300]
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                                Text(
                                                  uvImpact['label'],
                                                  style: TextStyle(
                                                    fontSize:
                                                        Responsive.fontSize(
                                                            context, 14),
                                                    fontWeight: FontWeight.bold,
                                                    color: impactColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                                height: Responsive.padding(
                                                    context, 6)),
                                            Container(
                                              height: Responsive.fontSize(
                                                  context, 8),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white
                                                        .withOpacity(0.1)
                                                    : Colors.grey[100],
                                                borderRadius:
                                                    BorderRadius.circular(9999),
                                              ),
                                              child: Stack(
                                                children: [
                                                  Container(
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              9999),
                                                    ),
                                                  ),
                                                  FractionallySizedBox(
                                                    widthFactor: impactScore
                                                        .clamp(0.0, 1.0),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: impactColor,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(9999),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: Responsive.padding(context, 24)),

                              // Action Buttons
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: Responsive.fontSize(context, 56),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        // lifestyle_id를 report_id로 전달하여 리포트 기반 코칭
                                        final rid = _lifestyleData?['lifestyle_id'] as int?;
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CoachChatScreen(reportId: rid),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF37EC13),
                                        foregroundColor:
                                            const Color(0xFF101B0D),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(9999),
                                        ),
                                        elevation: 0,
                                        shadowColor: const Color(0xFF37EC13)
                                            .withOpacity(0.3),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'View Action Plan',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 18),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(
                                              width: Responsive.padding(
                                                  context, 8)),
                                          Icon(
                                            Icons.arrow_forward,
                                            size: Responsive.iconSize(
                                                context, 20),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                      height: Responsive.padding(context, 12)),
                                  SizedBox(
                                    width: double.infinity,
                                    height: Responsive.fontSize(context, 56),
                                    child: OutlinedButton(
                                      onPressed: () {
                                        // TODO: Save comparison
                                        debugPrint('Save Comparison tapped');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark
                                            ? Colors.white
                                            : const Color(0xFF101B0D),
                                        side: BorderSide(
                                          color: isDark
                                              ? Colors.white.withOpacity(0.1)
                                              : Colors.grey[200]!,
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(9999),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.download,
                                            size: Responsive.iconSize(
                                                context, 20),
                                          ),
                                          SizedBox(
                                              width: Responsive.padding(
                                                  context, 8)),
                                          Text(
                                            'Save Comparison',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 16),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: Responsive.padding(context, 24)),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTargetAge() {
    if (_lifestyleData?['target_age'] != null) {
      final targetAgeStr = _lifestyleData!['target_age'].toString();
      // "X years after" 형식에서 숫자 추출
      final match = RegExp(r'(\d+)').firstMatch(targetAgeStr);
      if (match != null) {
        final years = int.tryParse(match.group(1) ?? '');
        if (years != null && _lifestyleData?['profile']?['age'] != null) {
          final currentAgeStr =
              _lifestyleData!['profile']['age'].toString().split(' ')[0];
          final currentAge = int.tryParse(currentAgeStr) ?? 0;
          return '${currentAge + years}';
        }
      }
    }
    return '65'; // 기본값
  }

  // 현재 나이 가져오기
  int _getCurrentAge() {
    if (_lifestyleData?['profile']?['age'] != null) {
      final ageStr = _lifestyleData!['profile']['age'].toString().split(' ')[0];
      return int.tryParse(ageStr) ?? 29;
    }
    return 29; // 기본값
  }

  // 타겟 연도 가져오기
  int _getTargetYears() {
    if (_lifestyleData?['target_age'] != null) {
      final targetAgeStr = _lifestyleData!['target_age'].toString();
      final match = RegExp(r'(\d+)').firstMatch(targetAgeStr);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '') ?? 36;
      }
    }
    return 36; // 기본값 (29 + 36 = 65)
  }

  // 생활습관 기반 피부 나이 가산점 계산 (관리했을 때)
  int _calculateManagedSkinAge(int currentAge, int targetYears) {
    final lifestyle = _lifestyleData?['lifestyle'];
    if (lifestyle == null) return currentAge + (targetYears ~/ 2);

    int agingFactor = 0;

    // 흡연 요인
    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        agingFactor += targetYears ~/ 3; // 현재 흡연은 피부 나이 증가
      } else if (status.contains('과거') || status.contains('past')) {
        agingFactor += targetYears ~/ 5; // 과거 흡연은 약간 증가
      }
    }

    // 운동 요인
    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType =
          exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        agingFactor += targetYears ~/ 4;
      }

      final dailyMins = exercise['daily_exercise_minutes'];
      if (dailyMins != null) {
        final minsStr = dailyMins.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final mins = int.tryParse(minsStr) ?? 0;
        if (mins < 30) {
          agingFactor += targetYears ~/ 6;
        }
      }
    }

    // 수면 요인
    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr =
            sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          agingFactor += targetYears ~/ 6;
        }
      }
    }

    // 자외선 노출 요인
    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') ||
          sunscreen.contains('none') ||
          sunscreen.contains('가끔')) {
        agingFactor += targetYears ~/ 2; // 자외선 차단제 미사용은 큰 영향
      }
    }

    // 음주 요인
    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency =
          drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        agingFactor += targetYears ~/ 4;
      } else if (frequency.contains('주3') || frequency.contains('주4')) {
        agingFactor += targetYears ~/ 5;
      }
    }

    // 관리했을 때는 가산점의 일부만 적용 (관리 효과 반영)
    final managedAge = currentAge + (agingFactor ~/ 3) + (targetYears ~/ 2);
    return managedAge;
  }

  // 생활습관 기반 피부 나이 가산점 계산 (관리하지 않았을 때)
  int _calculateUnmanagedSkinAge(int currentAge, int targetYears) {
    final lifestyle = _lifestyleData?['lifestyle'];
    if (lifestyle == null) return currentAge + targetYears;

    int agingFactor = 0;

    // 흡연 요인
    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        agingFactor += targetYears ~/ 2; // 현재 흡연은 큰 영향
      } else if (status.contains('과거') || status.contains('past')) {
        agingFactor += targetYears ~/ 3;
      }
    }

    // 운동 요인
    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType =
          exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        agingFactor += targetYears ~/ 2;
      }

      final dailyMins = exercise['daily_exercise_minutes'];
      if (dailyMins != null) {
        final minsStr = dailyMins.toString().replaceAll(RegExp(r'[^0-9]'), '');
        final mins = int.tryParse(minsStr) ?? 0;
        if (mins < 30) {
          agingFactor += targetYears ~/ 3;
        }
      }
    }

    // 수면 요인
    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr =
            sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          agingFactor += targetYears ~/ 3;
        }
      }
    }

    // 자외선 노출 요인 (가장 큰 영향)
    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') || sunscreen.contains('none')) {
        agingFactor += targetYears; // 자외선 차단제 미사용은 매우 큰 영향
      } else if (sunscreen.contains('가끔')) {
        agingFactor += targetYears ~/ 2;
      }
    }

    // 음주 요인
    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency =
          drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        agingFactor += targetYears ~/ 2;
      } else if (frequency.contains('주3') || frequency.contains('주4')) {
        agingFactor += targetYears ~/ 3;
      }
    }

    // 관리하지 않았을 때는 가산점을 모두 적용
    final unmanagedAge = currentAge + agingFactor + targetYears;
    return unmanagedAge;
  }

  // Visual Gap 계산 (피부 나이 차이)
  int _getVisualGap() {
    final currentAge = _getCurrentAge();
    final targetYears = _getTargetYears();
    final managedAge = _calculateManagedSkinAge(currentAge, targetYears);
    final unmanagedAge = _calculateUnmanagedSkinAge(currentAge, targetYears);
    return (unmanagedAge - managedAge).abs();
  }

  // Potential 계산 (개선 가능 퍼센트)
  double _getPotentialPercentage() {
    final currentAge = _getCurrentAge();
    final targetYears = _getTargetYears();
    final managedAge = _calculateManagedSkinAge(currentAge, targetYears);
    final unmanagedAge = _calculateUnmanagedSkinAge(currentAge, targetYears);

    if (unmanagedAge == 0) return 0.0;
    final difference = unmanagedAge - managedAge;
    final percentage = (difference / unmanagedAge) * 100;
    return percentage.abs();
  }

  // Critical Factors 계산 - 콜라겐 보존 영향도
  Map<String, dynamic> _getCollagenPreservationImpact() {
    final lifestyle = _lifestyleData?['lifestyle'];
    if (lifestyle == null) {
      return {'level': 'medium', 'score': 0.5, 'label': 'Medium Impact'};
    }

    double impactScore = 0.0;
    int factorCount = 0;

    // 흡연 요인
    final smoking = lifestyle['smoking'];
    if (smoking != null && smoking['smoking_status'] != null) {
      final status = smoking['smoking_status'].toString().toLowerCase();
      if (status.contains('현재') || status.contains('current')) {
        impactScore += 0.9;
        factorCount++;
      } else if (status.contains('과거') || status.contains('past')) {
        impactScore += 0.5;
        factorCount++;
      }
    }

    // 운동 요인
    final exercise = lifestyle['exercise'];
    if (exercise != null) {
      final exerciseType =
          exercise['exercise_type']?.toString().toLowerCase() ?? '';
      if (exerciseType.contains('안함') || exerciseType.contains('none')) {
        impactScore += 0.7;
        factorCount++;
      }
    }

    // 수면 요인
    final sleep = lifestyle['sleep'];
    if (sleep != null) {
      final sleepHours = sleep['average_sleep_hours'];
      if (sleepHours != null) {
        final hoursStr =
            sleepHours.toString().replaceAll(RegExp(r'[^0-9.]'), '');
        final hours = double.tryParse(hoursStr) ?? 7.0;
        if (hours < 6 || hours > 9) {
          impactScore += 0.6;
          factorCount++;
        }
      }
    }

    // 음주 요인
    final drinking = lifestyle['drinking'];
    if (drinking != null) {
      final frequency =
          drinking['drinking_frequency']?.toString().toLowerCase() ?? '';
      if (frequency.contains('매일') || frequency.contains('daily')) {
        impactScore += 0.8;
        factorCount++;
      }
    }

    final normalizedScore = factorCount > 0 ? impactScore / factorCount : 0.0;

    if (normalizedScore >= 0.7) {
      return {
        'level': 'high',
        'score': normalizedScore,
        'label': 'High Impact'
      };
    } else if (normalizedScore >= 0.4) {
      return {
        'level': 'medium',
        'score': normalizedScore,
        'label': 'Medium Impact'
      };
    } else {
      return {'level': 'low', 'score': normalizedScore, 'label': 'Low Impact'};
    }
  }

  // Critical Factors 계산 - 자외선 손상 관리 영향도
  Map<String, dynamic> _getUVDamageControlImpact() {
    final lifestyle = _lifestyleData?['lifestyle'];
    if (lifestyle == null) {
      return {'level': 'medium', 'score': 0.5, 'label': 'Medium Impact'};
    }

    double impactScore = 0.0;

    // 자외선 차단제 사용
    final uv = lifestyle['uv'];
    if (uv != null) {
      final sunscreen = uv['sunscreen_usage']?.toString().toLowerCase() ?? '';
      if (sunscreen.contains('안함') || sunscreen.contains('none')) {
        impactScore = 0.9; // 매우 높은 영향
      } else if (sunscreen.contains('가끔')) {
        impactScore = 0.6; // 중간 영향
      } else if (sunscreen.contains('매일') || sunscreen.contains('daily')) {
        impactScore = 0.2; // 낮은 영향 (잘 관리)
      }
    }

    if (impactScore >= 0.7) {
      return {'level': 'high', 'score': impactScore, 'label': 'High Impact'};
    } else if (impactScore >= 0.4) {
      return {
        'level': 'medium',
        'score': impactScore,
        'label': 'Medium Impact'
      };
    } else {
      return {'level': 'low', 'score': impactScore, 'label': 'Low Impact'};
    }
  }

  // 영향도 색상 가져오기
  Color _getImpactColor(String level) {
    switch (level) {
      case 'high':
        return Colors.red[500]!;
      case 'medium':
        return Colors.yellow[500]!;
      case 'low':
        return Colors.green[500]!;
      default:
        return Colors.grey[500]!;
    }
  }

  Widget _buildImageWidget(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.image,
              size: Responsive.iconSize(context, 64), color: Colors.grey),
        ),
      );
    }

    // 서버 URL을 통해 이미지 로드
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: const Color(0xFF37EC13),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: Center(
            child: Icon(Icons.image,
                size: Responsive.iconSize(context, 64), color: Colors.grey),
          ),
        );
      },
    );
  }
}
