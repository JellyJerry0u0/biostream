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

  /// visual_data가 List면 각 항목별 차트, Map이면 단일 차트 (하위 호환)
  List<Widget> _buildVisualWidgets(
    BuildContext ctx,
    dynamic visualData, {
    required bool isDark,
    required bool isGrounded,
  }) {
    final list = visualData is List
        ? visualData
            .map((e) => e is Map<String, dynamic> ? e : null)
            .whereType<Map<String, dynamic>>()
            .toList()
        : visualData is Map<String, dynamic>
            ? [visualData]
            : <Map<String, dynamic>>[];
    final spacer = Responsive.padding(ctx, 12);
    return list.asMap().entries.map((entry) {
      final idx = entry.key;
      final data = entry.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SimulationVisualWidget(
            visualData: data,
            isDark: isDark,
            isGrounded: isGrounded,
          ),
          if (idx < list.length - 1) SizedBox(height: spacer),
        ],
      );
    }).toList();
  }

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
    final visualData = meta?['visual_data']; // Map 또는 List<Map>

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
                Icons.trending_up,
                size: Responsive.iconSize(context, 20),
                color: Colors.blue[400],
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Expanded(
                child: Text(
                  '예상 효과',
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
                      ? Colors.green[900]!.withValues(alpha: 0.2)
                      : Colors.orange[900]!.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isGrounded ? '연구 근거 있음' : 'AI 추정',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 10),
                    fontWeight: FontWeight.w600,
                    color: isGrounded ? Colors.green[400] : Colors.orange[400],
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
          // 시각 자료 (visual_data 있을 때만) - 리스트면 전부, 단일 객체면 하나
          if (visualData != null) ...[
            SizedBox(height: Responsive.padding(context, 16)),
            ..._buildVisualWidgets(
              context,
              visualData,
              isDark: isDark,
              isGrounded: isGrounded,
            ),
          ],
          // Estimated일 때만 disclaimer 표시
          if (!isGrounded && disclaimer != null && disclaimer.isNotEmpty) ...[
            SizedBox(height: Responsive.padding(context, 12)),
            Container(
              padding: EdgeInsets.all(Responsive.padding(context, 12)),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[900]!.withValues(alpha: 0.3)
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

/// 예상 효과 시각화 (가로 막대: 0 ~ max, median 위치 표시)
class _SimulationVisualWidget extends StatelessWidget {
  final Map<String, dynamic> visualData;
  final bool isDark;
  final bool isGrounded;

  const _SimulationVisualWidget({
    required this.visualData,
    required this.isDark,
    required this.isGrounded,
  });

  @override
  Widget build(BuildContext context) {
    final outcome = visualData['outcome_label'] as String? ?? '예상 효과';
    final median = (visualData['median'] as num?)?.toDouble() ?? 0;
    final minVal = (visualData['min_val'] as num?)?.toDouble() ?? 0;
    final maxVal = (visualData['max_val'] as num?)?.toDouble() ?? 0;
    final timeframe = visualData['timeframe_label'] as String? ?? '';

    final barColor = isGrounded ? Colors.green : Colors.blue;
    final rawMax = [minVal, maxVal, median].reduce((a, b) => a > b ? a : b);
    final scaleMax = (rawMax > 25 ? rawMax + 5 : 30).clamp(10.0, 100.0);
    final scaleMin = minVal < 0 ? (minVal - 5).floorToDouble() : 0;
    final range = (scaleMax - scaleMin).clamp(1, 100);
    double toPos(double v) => ((v - scaleMin) / range).clamp(0.0, 1.0);
    final minPos = toPos(minVal);
    final maxPos = toPos(maxVal);
    final medianPos = toPos(median);

    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: (isDark ? Colors.grey[900] : Colors.grey[50])
            ?.withValues(alpha: isDark ? 0.5 : 1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: barColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart,
                size: Responsive.iconSize(context, 18),
                color: barColor[400],
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Text(
                '$outcome 예상 변화${timeframe.isNotEmpty ? ' ($timeframe)' : ''}',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.padding(context, 12)),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final trackH = 12.0;
              return SizedBox(
                height: trackH + 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // 배경 트랙
                          Container(
                            width: w,
                            height: trackH,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(trackH / 2),
                            ),
                          ),
                          // 범위 (min~max) - 연한 색
                          Positioned(
                            left: minPos * w,
                            child: Container(
                              width: (maxPos - minPos).clamp(0.02, 1) * w,
                              height: trackH,
                              decoration: BoxDecoration(
                                color: barColor.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(trackH / 2),
                              ),
                            ),
                          ),
                          // 중앙값 바 (0 ~ median)
                          Positioned(
                            left: 0,
                            child: Container(
                              width: medianPos * w,
                              height: trackH,
                              decoration: BoxDecoration(
                                color: barColor[400],
                                borderRadius: BorderRadius.circular(trackH / 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 4)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${scaleMin.toInt()}%',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 10),
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${scaleMax.toInt()}%',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 10),
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            '약 ${median.toStringAsFixed(1)}% 예상 (범위 ${minVal.toStringAsFixed(1)}~${maxVal.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 11),
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
