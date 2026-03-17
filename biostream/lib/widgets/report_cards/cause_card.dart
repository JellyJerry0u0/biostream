import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class CauseCard extends StatelessWidget {
  final String text;

  const CauseCard({
    super.key,
    required this.text,
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
    final cleanedText = _removeCitationLeaks(text);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline,
                size: Responsive.iconSize(context, 20),
                color: Colors.orange[400],
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Text(
                '왜 이런 상태인가',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 12)),
          Text(
            cleanedText,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              height: 1.6,
              color: isDark ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
