import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class ActionCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const ActionCard({
    super.key,
    required this.items,
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
            ...List.generate(3 - items.length, (index) => {
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
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: Responsive.iconSize(context, 20),
                color: const Color(0xFF37EC13),
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Text(
                '당신에게 필요한 행동 3가지',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          ...displayItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final title = _removeCitationLeaks(item['title'] ?? '');
            final detail = _removeCitationLeaks(item['detail'] ?? '');

            return Padding(
              padding: EdgeInsets.only(
                bottom: Responsive.padding(context, 12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: Responsive.fontSize(context, 24),
                    height: Responsive.fontSize(context, 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF37EC13).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF37EC13),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.padding(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: Responsive.padding(context, 4)),
                        Text(
                          detail,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 13),
                            height: 1.4,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
