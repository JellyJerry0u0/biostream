import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class EvidenceModal extends StatelessWidget {
  final Map<String, dynamic> evidenceRefs;

  const EvidenceModal({
    super.key,
    required this.evidenceRefs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 안전하게 데이터 추출
    final narrativeRefs = (evidenceRefs['narrative'] is List)
        ? evidenceRefs['narrative'] as List<dynamic>
        : <dynamic>[];
    final quantRefs = (evidenceRefs['quant'] is List)
        ? evidenceRefs['quant'] as List<dynamic>
        : <dynamic>[];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2C17) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (고정)
          Container(
            padding: EdgeInsets.all(Responsive.padding(context, 24)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '근거 보기',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // 스크롤 가능한 내용
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 24),
                vertical: Responsive.padding(context, 8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 정량 근거
          if (quantRefs.isNotEmpty) ...[
            Text(
              '정량 근거',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: const Color(0xFF37EC13),
              ),
            ),
            SizedBox(height: Responsive.padding(context, 12)),
            ...quantRefs.take(5).map((ref) {
              if (ref is! Map<String, dynamic>) {
                return SizedBox.shrink();
              }
              final refMap = ref;
              final outcome = refMap['outcome_mapped']?.toString() ?? '';
              final timeframe = refMap['timeframe_days']?.toString() ?? '';
              final effect = refMap['effect_signed_value']?.toString() ?? '';
              final unit = refMap['effect_unit']?.toString() ?? '%';
              final pLabel = refMap['p_label']?.toString() ?? '';
              final sourceSnippet = refMap['source_snippet']?.toString();

              return _buildExpandableCard(
                context,
                isDark,
                title: outcome.isNotEmpty ? outcome : '정량 근거',
                subtitle: '${timeframe}일 후: $effect$unit${pLabel.isNotEmpty ? ' (근거 강도: $pLabel)' : ''}',
                content: sourceSnippet,
              );
            }).where((widget) => widget is! SizedBox).toList(),
            SizedBox(height: Responsive.padding(context, 24)),
          ],

          // 서술 근거
          if (narrativeRefs.isNotEmpty) ...[
            Text(
              '서술 근거',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 16),
                fontWeight: FontWeight.bold,
                color: Colors.blue[400],
              ),
            ),
            SizedBox(height: Responsive.padding(context, 12)),
            ...narrativeRefs.take(5).map((ref) {
              if (ref is! Map<String, dynamic>) {
                return SizedBox.shrink();
              }
              final refMap = ref;
              final title = refMap['title']?.toString() ?? '';
              final paperId = refMap['paper_id']?.toString() ?? '';
              final chunkId = refMap['chunk_id']?.toString() ?? '';

              return Container(
                margin: EdgeInsets.only(bottom: Responsive.padding(context, 8)),
                padding: EdgeInsets.all(Responsive.padding(context, 12)),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 13),
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    SizedBox(height: Responsive.padding(context, 4)),
                    Text(
                      'Paper ID: $paperId | Chunk: $chunkId',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 11),
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }).where((widget) => widget is! SizedBox).toList(),
          ],

                  if (quantRefs.isEmpty && narrativeRefs.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(Responsive.padding(context, 24)),
                        child: Text(
                          '근거 정보가 없습니다.',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 14),
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: Responsive.padding(context, 24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCard(
    BuildContext context,
    bool isDark, {
    required String title,
    required String subtitle,
    String? content,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {

        return Container(
          margin: EdgeInsets.only(bottom: Responsive.padding(context, 8)),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(Responsive.padding(context, 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 4)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 11),
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (content != null && content.isNotEmpty) ...[
                      SizedBox(height: Responsive.padding(context, 8)),
                      Text(
                        content,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
