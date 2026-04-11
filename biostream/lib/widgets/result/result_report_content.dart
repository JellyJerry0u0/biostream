import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../evidence_modal.dart';
import '../report_cards/action_card.dart';
import '../report_cards/cause_card.dart';
import '../report_cards/problem_card.dart';
import '../report_cards/simulation_card.dart';
import '../report_tabs_bar.dart';
import 'result_summary_section.dart';

class ResultReportContent extends StatefulWidget {
  final Map<String, dynamic>? reportData;
  final String? selectedTab;
  final ValueChanged<String> onTabSelected;
  final bool isDark;
  final void Function(String title, String detail, String sectionKey)? onAddToHabit;
  final void Function(String title)? onRemoveFromHabit;
  final bool Function(String title)? isInPendingList;
  final bool habitQuestFull;

  const ResultReportContent({
    super.key,
    required this.reportData,
    required this.selectedTab,
    required this.onTabSelected,
    required this.isDark,
    this.onAddToHabit,
    this.onRemoveFromHabit,
    this.isInPendingList,
    this.habitQuestFull = false,
  });

  @override
  State<ResultReportContent> createState() => _ResultReportContentState();
}

class _ResultReportContentState extends State<ResultReportContent>
    with SingleTickerProviderStateMixin {
  static const Duration _fadeOut = Duration(milliseconds: 260);
  static const Duration _fadeIn = Duration(milliseconds: 480);

  late final AnimationController _fade;
  String? _shownTab;
  Future<void> _transitionTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(vsync: this, duration: _fadeIn);
    _shownTab = widget.selectedTab;
    _fade.value = _shownTab != null ? 1.0 : 0.0;
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ResultReportContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTab == null) return;
    if (oldWidget.selectedTab != widget.selectedTab) {
      _transitionTail = _transitionTail.then((_) => _fadeThroughToSelectedTab());
    }
  }

  /// AnimatedSwitcher 대신 순차 페이드: 한 시점에 본문 트리는 하나만 유지 → 스크롤·카드 많을 때 덜 끊김.
  /// 빠른 연속 탭은 Future 체인으로 같은 컨트롤러에 순서대로만 건다.
  Future<void> _fadeThroughToSelectedTab() async {
    while (mounted && widget.selectedTab != _shownTab) {
      _fade.duration = _fadeOut;
      await _fade.animateTo(0, curve: Curves.easeIn);
      if (!mounted) return;
      setState(() => _shownTab = widget.selectedTab);
      _fade.duration = _fadeIn;
      await _fade.animateTo(1, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.reportData?['tabs'] as List<dynamic>? ?? [];
    final sections =
        widget.reportData?['sections'] as Map<String, dynamic>? ?? {};
    if (tabs.isEmpty || widget.selectedTab == null) {
      return _buildErrorSection(context, '리포트 데이터가 없습니다.');
    }

    final barTab = widget.selectedTab!;
    final bodyTab = _shownTab ?? barTab;

    return Column(
      children: [
        ReportTabsBar(
          tabs: tabs.cast<String>(),
          selectedTab: barTab,
          onTabSelected: widget.onTabSelected,
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        RepaintBoundary(
          child: FadeTransition(
            opacity: _fade,
            child: _buildBodyForTab(context, sections, bodyTab),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyForTab(
    BuildContext context,
    Map<String, dynamic> sections,
    String tab,
  ) {
    if (sections.containsKey(tab)) {
      return _buildSectionView(
        context,
        sections[tab] as Map<String, dynamic>,
        tab,
      );
    }
    return _buildErrorSection(context, '섹션 데이터를 찾을 수 없습니다.');
  }

  Widget _buildSectionView(
    BuildContext context,
    Map<String, dynamic> sectionData,
    String sectionTab,
  ) {
    if (sectionData['is_summary'] == true) {
      final summaryData =
          sectionData['summary_data'] as Map<String, dynamic>? ?? {};
      return ResultSummarySection(
        summaryData: summaryData,
        isDark: widget.isDark,
      );
    }

    final title = sectionData['title'] as String? ?? '';
    final cards = sectionData['cards'] as List<dynamic>?;
    final evidenceRefs =
        sectionData['evidence_refs'] as Map<String, dynamic>? ?? {};

    final displayCards = _ensureFourCards(cards ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title, evidenceRefs),
        SizedBox(height: Responsive.padding(context, 16)),
        ..._buildCards(context, displayCards, sectionTab),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    Map<String, dynamic> evidenceRefs,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 20),
              fontWeight: FontWeight.bold,
              color: widget.isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) => EvidenceModal(evidenceRefs: evidenceRefs),
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
    );
  }

  List<Widget> _buildCards(
    BuildContext context,
    List<Map<String, dynamic>> cards,
    String sectionTab,
  ) {
    return cards.map((card) {
      final cardType = card['type'] as String? ?? '';
      switch (cardType) {
        case 'problem':
          return ProblemCard(text: card['text'] ?? '');
        case 'cause':
          return CauseCard(text: card['text'] ?? '');
        case 'action':
          final items = card['items'] as List<dynamic>? ?? [];
          return ActionCard(
            items: items.map((item) => item as Map<String, dynamic>).toList(),
            sectionKey: sectionTab,
            onAddToHabit: widget.onAddToHabit,
            onRemoveFromHabit: widget.onRemoveFromHabit,
            isInPendingList: widget.isInPendingList,
            habitQuestFull: widget.habitQuestFull,
          );
        case 'simulation':
          return SimulationCard(
            text: card['text'] ?? '',
            meta: card['meta'] as Map<String, dynamic>?,
          );
        default:
          return Container();
      }
    }).toList();
  }

  List<Map<String, dynamic>> _ensureFourCards(List<dynamic> cards) {
    final result = <Map<String, dynamic>>[];
    for (final card in cards) {
      if (card is Map<String, dynamic>) {
        result.add(card);
      }
    }

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
        return '예상 효과';
      default:
        return '';
    }
  }

  Widget _buildErrorSection(BuildContext context, String message) {
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
}
