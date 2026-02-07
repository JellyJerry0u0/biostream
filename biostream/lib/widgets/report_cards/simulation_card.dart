import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class SimulationCard extends StatelessWidget {
  final String text;
  final Map<String, dynamic>? meta;

  const SimulationCard({
    super.key,
    required this.text,
    this.meta,
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
    final mode = meta?['mode'] ?? 'estimated';
    final isGrounded = mode == 'grounded';
    final disclaimer = meta?['disclaimer_small'] as String?;

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
                Icons.trending_up,
                size: Responsive.iconSize(context, 20),
                color: Colors.blue[400],
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: Text(
                  '예상 경로',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 16),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              // 배지
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 8),
                  vertical: Responsive.padding(context, 4),
                ),
                decoration: BoxDecoration(
                  color: isGrounded
                      ? Colors.green[900]!.withOpacity(0.2)
                      : Colors.orange[900]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isGrounded ? '연구 근거 있음' : 'AI 추정',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 10),
                    fontWeight: FontWeight.w600,
                    color: isGrounded
                        ? Colors.green[400]
                        : Colors.orange[400],
                  ),
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
          // Estimated일 때만 disclaimer 표시
          if (!isGrounded && disclaimer != null && disclaimer.isNotEmpty) ...[
            SizedBox(height: Responsive.padding(context, 12)),
            Container(
              padding: EdgeInsets.all(Responsive.padding(context, 12)),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[900]!.withOpacity(0.3)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                disclaimer,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 11),
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
