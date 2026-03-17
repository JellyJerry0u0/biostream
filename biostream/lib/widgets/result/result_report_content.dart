import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../evidence_modal.dart';
import '../report_cards/action_card.dart';
import '../report_cards/cause_card.dart';
import '../report_cards/problem_card.dart';
import '../report_cards/simulation_card.dart';
import '../report_tabs_bar.dart';

class ResultReportContent extends StatelessWidget {
  final Map<String, dynamic>? reportData;
  final String? selectedTab;
  final ValueChanged<String> onTabSelected;
  final String? selectedLifestyleSubTab;
  final ValueChanged<String> onLifestyleSubTabChanged;
  final bool isDark;

  const ResultReportContent({
    super.key,
    required this.reportData,
    required this.selectedTab,
    required this.onTabSelected,
    required this.selectedLifestyleSubTab,
    required this.onLifestyleSubTabChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = reportData?['tabs'] as List<dynamic>? ?? [];
    final sections = reportData?['sections'] as Map<String, dynamic>? ?? {};
    if (tabs.isEmpty || selectedTab == null) {
      return _buildErrorSection(context, '리포트 데이터가 없습니다.');
    }

    return Column(
      children: [
        ReportTabsBar(
          tabs: tabs.cast<String>(),
          selectedTab: selectedTab!,
          onTabSelected: onTabSelected,
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        if (sections.containsKey(selectedTab))
          _buildSectionView(
              context, sections[selectedTab] as Map<String, dynamic>)
        else
          _buildErrorSection(context, '섹션 데이터를 찾을 수 없습니다.'),
      ],
    );
  }

  Widget _buildSectionView(
      BuildContext context, Map<String, dynamic> sectionData) {
    final title = sectionData['title'] as String? ?? '';
    final cards = sectionData['cards'] as List<dynamic>?;
    final subsections = sectionData['subsections'] as List<dynamic>?;
    final evidenceRefs =
        sectionData['evidence_refs'] as Map<String, dynamic>? ?? {};

    if (subsections != null && subsections.isNotEmpty) {
      final selectedSubKey = selectedLifestyleSubTab ??
          (subsections[0] as Map<String, dynamic>)['key'] as String? ??
          '';

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
          _buildSectionHeader(context, title, evidenceRefs),
          SizedBox(height: Responsive.padding(context, 12)),
          Container(
            height: Responsive.fontSize(context, 42),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
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
                    onTap: () => onLifestyleSubTabChanged(subKey),
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
                                      .withValues(alpha: 0.3),
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
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.w500,
                            color: isActive
                                ? const Color(0xFF101B0D)
                                : (isDark ? Colors.white60 : Colors.grey[600]),
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
          ..._buildCards(displayCards),
        ],
      );
    }

    final displayCards = _ensureFourCards(cards ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title, evidenceRefs),
        SizedBox(height: Responsive.padding(context, 16)),
        ..._buildCards(displayCards),
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

  List<Widget> _buildCards(List<Map<String, dynamic>> cards) {
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
