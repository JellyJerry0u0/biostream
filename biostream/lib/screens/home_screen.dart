import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/lifestyle_service.dart';
import 'coach_chat_screen.dart';
import 'facescan_screen.dart';
import 'future_face_compare_screen.dart';
import 'my_info_screen.dart';
import 'result_screen.dart';
import 'today_me_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _primary = Color(0xFF2BEE75);
  static const Color _backgroundLight = Color(0xFFF6F8F6);
  static const Color _backgroundDark = Color(0xFF050C08);
  static const Color _gameCard = Color(0xFF0D1F14);

  final LifestyleService _lifestyleService = LifestyleService();

  bool _isLoadingQuests = true;
  String? _questError;
  int? _lifestyleId;
  List<_QuestItem> _questItems = [];
  String? _originalImageUrl;
  String? _generatedImageUrl;
  String? _predictionPoint;

  @override
  void initState() {
    super.initState();
    _loadQuestFromReport();
  }

  Future<void> _loadQuestFromReport() async {
    setState(() {
      _isLoadingQuests = true;
      _questError = null;
    });

    final lifestyleResult = await _lifestyleService.getLifestyleData();
    if (!mounted) return;

    if (lifestyleResult['success'] != true) {
      setState(() {
        _isLoadingQuests = false;
        _questError = '생활습관 데이터를 불러오지 못했습니다.';
      });
      return;
    }

    final lifestyleData = lifestyleResult['data'];
    final images = lifestyleData is Map<String, dynamic>
        ? lifestyleData['images'] as Map<String, dynamic>?
        : null;

    _originalImageUrl = images?['original_image_url']?.toString();
    _generatedImageUrl = images?['generated_image_url']?.toString();

    final lifestyleId = _toInt(
      lifestyleData is Map<String, dynamic> ? lifestyleData['lifestyle_id'] : null,
    );

    if (lifestyleId == null) {
      setState(() {
        _isLoadingQuests = false;
        _questError = '분석 리포트가 아직 없습니다.';
      });
      return;
    }

    final reportResult = await _lifestyleService.getHealthReport(lifestyleId);
    if (!mounted) return;

    if (reportResult['success'] != true) {
      setState(() {
        _isLoadingQuests = false;
        _questError = '리포트를 불러오지 못했습니다.';
      });
      return;
    }

    final report = reportResult['report'];
    _predictionPoint = _extractPredictionPoint(report);

    final reportGeneratedImage = _extractGeneratedImageFromReport(report);
    if ((_generatedImageUrl == null || _generatedImageUrl!.isEmpty) &&
        reportGeneratedImage.isNotEmpty) {
      _generatedImageUrl = reportGeneratedImage;
    }

    final extractedItems = _extractSolutionItems(report);
    final completedIdsFromServer = _extractCompletedIdsFromServer(report);

    if (extractedItems.isEmpty) {
      setState(() {
        _lifestyleId = lifestyleId;
        _isLoadingQuests = false;
        _questError = '맞춤 솔루션이 아직 생성되지 않았습니다.';
        _questItems = [];
      });
      return;
    }

    if (completedIdsFromServer.isNotEmpty) {
      for (final item in extractedItems) {
        item.isDone = completedIdsFromServer.contains(item.id);
      }
      await _savePracticedStateToLocal(lifestyleId, extractedItems);
    } else {
      await _restorePracticedStateFromLocal(lifestyleId, extractedItems);
    }

    if (!mounted) return;

    setState(() {
      _lifestyleId = lifestyleId;
      _questItems = extractedItems;
      _isLoadingQuests = false;
      _questError = null;
    });
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<_QuestItem> _extractSolutionItems(dynamic report) {
    final items = <_QuestItem>[];
    final seenTitles = <String>{};

    void addItem(String title, String detail) {
      final normalizedTitle = _cleanText(title);
      final normalizedDetail = _cleanText(detail);

      if (normalizedTitle.isEmpty) return;
      if (seenTitles.contains(normalizedTitle)) return;

      seenTitles.add(normalizedTitle);
      items.add(
        _QuestItem(
          id: normalizedTitle,
          title: normalizedTitle,
          detail: normalizedDetail,
        ),
      );
    }

    void collectCards(dynamic cards) {
      if (cards is! List) return;
      for (final card in cards) {
        if (card is! Map<String, dynamic>) continue;
        if (card['type'] != 'action') continue;

        final cardItems = card['items'];
        if (cardItems is! List) continue;

        for (final entry in cardItems) {
          if (entry is! Map<String, dynamic>) continue;
          final title = (entry['title'] ?? '').toString();
          final detail = (entry['detail'] ?? '').toString();
          addItem(title, detail);
        }
      }
    }

    void collectSection(dynamic section) {
      if (section is! Map<String, dynamic>) return;
      collectCards(section['cards']);

      final subsections = section['subsections'];
      if (subsections is List) {
        for (final subsection in subsections) {
          collectSection(subsection);
        }
      }
    }

    if (report is Map<String, dynamic>) {
      final sections = report['sections'];
      if (sections is Map<String, dynamic>) {
        for (final section in sections.values) {
          collectSection(section);
        }
      }

      collectCards(report['cards']);

      final actionItems = report['action_items'];
      if (actionItems is List) {
        for (final entry in actionItems) {
          if (entry is! Map<String, dynamic>) continue;
          addItem((entry['title'] ?? '').toString(), (entry['detail'] ?? '').toString());
        }
      }
    }

    return items.take(3).toList();
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'PMC\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'PMID\s*:?\s*\d+', caseSensitive: false), '')
        .trim();
  }

  String _extractGeneratedImageFromReport(dynamic report) {
    if (report is! Map<String, dynamic>) return '';
    final generatedImage = report['generated_image_url']?.toString() ?? '';
    return generatedImage.trim();
  }

  String _extractPredictionPoint(dynamic report) {
    if (report is! Map<String, dynamic>) return '';

    String extractFromCards(List<dynamic>? cards) {
      if (cards == null) return '';
      for (final card in cards) {
        if (card is! Map<String, dynamic>) continue;
        if (card['type'] != 'simulation') continue;
        final rawText = (card['text'] ?? '').toString().trim();
        if (rawText.isNotEmpty) {
          final firstSentence = rawText.split(RegExp(r'[.!?\n]')).first.trim();
          return firstSentence;
        }
      }
      return '';
    }

    final sections = report['sections'];
    if (sections is Map<String, dynamic>) {
      for (final section in sections.values) {
        if (section is! Map<String, dynamic>) continue;
        final direct = extractFromCards(section['cards'] as List<dynamic>?);
        if (direct.isNotEmpty) return direct;

        final subsections = section['subsections'];
        if (subsections is List) {
          for (final subsection in subsections) {
            if (subsection is! Map<String, dynamic>) continue;
            final fromSub = extractFromCards(subsection['cards'] as List<dynamic>?);
            if (fromSub.isNotEmpty) return fromSub;
          }
        }
      }
    }

    final cards = report['cards'];
    if (cards is List<dynamic>) {
      final fromRoot = extractFromCards(cards);
      if (fromRoot.isNotEmpty) return fromRoot;
    }

    return '';
  }

  String _questStorageKey(int lifestyleId) => 'home_quest_done_$lifestyleId';

  Set<String> _extractCompletedIdsFromServer(dynamic report) {
    if (report is! Map<String, dynamic>) {
      return <String>{};
    }

    final questProgress = report['quest_progress'];
    if (questProgress is! Map<String, dynamic>) {
      return <String>{};
    }

    final completed = questProgress['completed_action_ids'];
    if (completed is! List) {
      return <String>{};
    }

    return completed
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  Future<void> _restorePracticedStateFromLocal(int lifestyleId, List<_QuestItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final doneIds = prefs.getStringList(_questStorageKey(lifestyleId)) ?? [];
    for (final item in items) {
      item.isDone = doneIds.contains(item.id);
    }
  }

  Future<void> _savePracticedStateToLocal(int lifestyleId, List<_QuestItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final doneIds = items
        .where((item) => item.isDone)
        .map((item) => item.id)
        .toList();

    await prefs.setStringList(_questStorageKey(lifestyleId), doneIds);
  }

  Future<void> _savePracticedStateToServer(int lifestyleId, List<_QuestItem> items) async {
    final doneIds = items.where((item) => item.isDone).map((item) => item.id).toList();
    final result = await _lifestyleService.updateQuestProgress(lifestyleId, doneIds);
    if (!mounted) return;

    if (result['success'] != true) {
      final message = (result['message'] ?? '퀘스트 저장에 실패했습니다.').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _toggleQuestItem(_QuestItem item) async {
    final lifestyleId = _lifestyleId;

    setState(() {
      item.isDone = !item.isDone;
    });

    if (lifestyleId == null) return;

    await _savePracticedStateToLocal(lifestyleId, _questItems);
    await _savePracticedStateToServer(lifestyleId, _questItems);
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 108),
                child: SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        _buildEngineLabel(),
                        const SizedBox(height: 28),
                        _buildSimulationSection(context),
                        const SizedBox(height: 16),
                        _buildRecentPredictionSection(context),
                        const SizedBox(height: 20),
                        _buildQuestSection(context),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomNavigation(context),
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: Center(
                  child: Container(
                    width: 128,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
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
    return Container(
      height: 256,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.15),
            blurRadius: 30,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAqdPZ9vYSCR_uxbMvaZXz8CoKZk7C4HEgzibttSr0a6H0rqO9PqtmOlRhp5gNEnBf3AecYZamAOsoS577N5fqTGfoGqGW4NfMcACIek9httob2CDPOhZh1VgBC-vzT95VddwkJdPS5DXhPP8qDAF7vlIlHgcqd9jVK7c_1Kj4zpLlfJpfLY5Vv2XQNolEmv_TxBGz3_gpADtnqOdrwJKU9athsm3v21Ev1u7D1PFf_3J64GiH8obx1l3XN6Do8kqEPc9VHUwAJ_qw',
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.6),
            colorBlendMode: BlendMode.darken,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _backgroundDark.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI PREDICT',
                          style: TextStyle(
                            color: _backgroundDark,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '미래 시뮬레이션',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '생활 습관 기반의 노화 타임랩스',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FaceScanScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.3),
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: _backgroundDark,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestSection(BuildContext context) {
    final int totalCount = _questItems.length;
    final int doneCount = _questItems.where((item) => item.isDone).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _gameCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: _primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                '오늘의 퀘스트',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$doneCount/$totalCount 완료',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '당신을 위한 맞춤 솔루션',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingQuests)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: _primary),
              ),
            )
          else if (_questError != null)
            _buildQuestFallback(context)
          else
            ..._questItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildQuestItem(item),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentPredictionSection(BuildContext context) {
    final hasOriginal = _originalImageUrl != null && _originalImageUrl!.isNotEmpty;
    final hasGenerated = _generatedImageUrl != null && _generatedImageUrl!.isNotEmpty;
    final hasPoint = _predictionPoint != null && _predictionPoint!.isNotEmpty;

    if (!hasOriginal && !hasGenerated && !hasPoint) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 노화 예측 결과',
              style: TextStyle(
                color: Color(0xFF102217),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ResultScreen()),
                );
              },
              child: const Text(
                '전체 보기',
                style: TextStyle(
                  color: _primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gameCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              _buildPredictionImage(
                imageUrl: _originalImageUrl,
                fallbackLabel: 'NOW',
              ),
              const SizedBox(width: 10),
              _buildPredictionImage(
                imageUrl: _generatedImageUrl,
                fallbackLabel: '+YEARS',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '예측 포인트',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasPoint ? _predictionPoint! : '최근 예측 결과를 확인해보세요.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ResultScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: _backgroundDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text(
                          'AI 분석 리포트',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionImage({
    required String? imageUrl,
    required String fallbackLabel,
  }) {
    return Container(
      width: 78,
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: 0.25)),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.white.withValues(alpha: 0.04),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              color: Colors.white.withValues(alpha: 0.04),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_outlined,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                fallbackLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestFallback(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _questError ?? '맞춤 솔루션을 불러오지 못했습니다.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FaceScanScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: BorderSide(color: _primary.withValues(alpha: 0.25)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('리포트 만들러 가기'),
          ),
        ),
      ],
    );
  }

  void _showQuestDetailDialog(_QuestItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 360,
              minHeight: 180,
              maxHeight: 320,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '퀘스트 상세보기',
                          style: TextStyle(
                            color: Color(0xFF102217),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF4D5C54),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE6ECE8)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Color(0xFF102217),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          item.detail.trim().isNotEmpty
                              ? item.detail
                              : '상세 설명이 아직 없습니다.',
                          style: const TextStyle(
                            color: Color(0xFF24352D),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestItem(_QuestItem item) {
    final bool isDone = item.isDone;

    return InkWell(
      onTap: () => _toggleQuestItem(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDone
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? _primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDone
                    ? _primary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone
                    ? _primary
                    : Colors.white.withValues(alpha: 0.25),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isDone
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _showQuestDetailDialog(item),
                      style: TextButton.styleFrom(
                        foregroundColor: _primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        '상세보기',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.timer,
                label: '오늘의 나',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TodayMeScreen()),
                  );
                },
              ),
              _NavItem(
                icon: Icons.assignment,
                label: '설문 조사',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FaceScanScreen()),
                  );
                },
              ),
              const _NavItem(
                icon: Icons.home,
                label: '홈 화면',
                isActive: true,
              ),
              _NavItem(
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
              _NavItem(
                icon: Icons.chat_bubble,
                label: '챗봇',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoachChatScreen()),
                  );
                },
              ),
              _NavItem(
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
        ),
      ),
    );
  }
}

class _QuestItem {
  _QuestItem({
    required this.id,
    required this.title,
    required this.detail,
    this.isDone = false,
  });

  final String id;
  final String title;
  final String detail;
  bool isDone;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
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
    const Color primary = Color(0xFF2BEE75);
    final Color itemColor = isActive ? primary : const Color(0xFF7A8380);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: itemColor, size: 23),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: itemColor,
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
