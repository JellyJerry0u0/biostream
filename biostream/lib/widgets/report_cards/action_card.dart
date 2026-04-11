import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class ActionCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String? sectionKey;
  final void Function(String title, String detail, String sectionKey)? onAddToHabit;
  final void Function(String title)? onRemoveFromHabit;
  final bool Function(String title)? isInPendingList;
  /// true면 +로 생활습관에 담을 수 없음(저장 한도 등)
  final bool habitQuestFull;

  const ActionCard({
    super.key,
    required this.items,
    this.sectionKey,
    this.onAddToHabit,
    this.onRemoveFromHabit,
    this.isInPendingList,
    this.habitQuestFull = false,
  });

  String _removeCitationLeaks(String text) {
    return text
        .replaceAll(RegExp(r'PMC\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'PMID\s*:?\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'p\s*[=<>]\s*[\d.]+', caseSensitive: false), '')
        .replaceAll(RegExp(r'CI\s*:?\s*\[[^\]]+\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 항상 3개 아이템 보장
    final displayItems = items.length >= 3
        ? items.sublist(0, 3)
        : [
            ...items,
            ...List.generate(
                3 - items.length,
                (index) => {
                      'title': '행동 ${items.length + index + 1}',
                      'detail': '분석 중입니다.',
                    }),
          ];

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.padding(context, 16)),
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2C17) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: Responsive.iconSize(context, 20),
                color: const Color(0xFF37EC13),
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: Text(
                  '당신에게 필요한 행동 3가지',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          ...() {
            final gapBetweenRows = Responsive.padding(context, 10);
            // 헤더(체크 아이콘+간격)와 동일한 위치에서 본문이 시작
            final headerTextInset = Responsive.iconSize(context, 20) +
                Responsive.padding(context, 8);
            // 숫자 끝과 제목 사이 최소 간격(열 너비는 그대로라 정렬 유지)
            final numberTailGap = Responsive.padding(context, 10);
            return displayItems.asMap().entries.expand((entry) {
              final index = entry.key;
              final item = entry.value;
              final title = _removeCitationLeaks(item['title'] ?? '');
              final detail = _removeCitationLeaks(item['detail'] ?? '');
              final hasAdd = onAddToHabit != null &&
                  sectionKey != null &&
                  sectionKey!.isNotEmpty &&
                  title.isNotEmpty;
              final canAdd = hasAdd && !habitQuestFull;
              final inList = (isInPendingList ?? (_) => false)(title);
              // 한도가 찼어도 탭하면 상위에서 안내 팝업을 띄울 수 있게 onAddToHabit 호출
              final canTapRow = inList
                  ? (onRemoveFromHabit != null)
                  : (hasAdd && (canAdd || habitQuestFull));
              final radius = BorderRadius.circular(12);
              const borderW = 1.5;

              final rowBody = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: headerTextInset,
                    child: Padding(
                      padding: EdgeInsets.only(right: numberTailGap),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Text(
                          '${index + 1}.',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: const Color(0xFF37EC13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: Responsive.padding(context, 5)),
                        Text(
                          detail,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 13),
                            height: 1.4,
                            color:
                                isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        if (habitQuestFull && !inList && hasAdd)
                          Padding(
                            padding: EdgeInsets.only(
                                top: Responsive.padding(context, 6)),
                            child: Text(
                              '생활습관 저장 한도에 도달했습니다',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 11),
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );

              // 왼쪽 0으로 헤더와 제목 시작선 유지, 테두리 안쪽 우·하에 여백
              final rowPad = EdgeInsets.fromLTRB(
                0,
                Responsive.padding(context, 14),
                Responsive.padding(context, 14),
                Responsive.padding(context, 14),
              );
              final bordered = Container(
                width: double.infinity,
                padding: rowPad,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: inList
                        ? const Color(0xFF37EC13)
                        : Colors.transparent,
                    width: borderW,
                  ),
                ),
                child: rowBody,
              );

              final rowShell = hasAdd
                  ? Tooltip(
                      message: habitQuestFull
                          ? '생활습관 저장 한도에 도달했습니다'
                          : (inList
                              ? '탭하여 담기 취소'
                              : '탭하여 생활습관에 담기'),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: radius,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: canTapRow
                              ? () {
                                  if (inList) {
                                    onRemoveFromHabit!(title);
                                  } else {
                                    onAddToHabit!(title, detail, sectionKey!);
                                  }
                                }
                              : null,
                          borderRadius: radius,
                          child: bordered,
                        ),
                      ),
                    )
                  : (inList
                      ? bordered
                      : Padding(
                          padding: rowPad,
                          child: rowBody,
                        ));

              return [
                if (index > 0) SizedBox(height: gapBetweenRows),
                rowShell,
              ];
            });
          }(),
        ],
      ),
    );
  }
}
