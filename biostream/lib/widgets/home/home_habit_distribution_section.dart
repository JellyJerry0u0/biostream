import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../screens/home/home_models.dart';

String _sectionLabelKo(String key) {
  switch (key) {
    case 'goals':
      return '피부 목표';
    case 'sleep':
      return '수면';
    case 'uv':
      return '자외선';
    case 'lifestyle':
      return '생활습관';
    case 'activity':
      return '활동·운동';
    case 'summary':
      return '요약';
    case 'smoking':
      return '흡연';
    case 'drinking':
      return '음주';
    case 'stress':
      return '스트레스';
    case 'other':
      return '기타';
    default:
      if (key.isEmpty) return '기타';
      return key;
  }
}

const List<Color> _sliceColors = [
  Color(0xFF2BEE75),
  Color(0xFF5B8DEF),
  Color(0xFFFFB74D),
  Color(0xFFE57373),
  Color(0xFFBA68C8),
  Color(0xFF4DD0E1),
  Color(0xFFFFD54F),
  Color(0xFF90A4AE),
];

/// 저장(또는 리포트 추천) 생활습관을 리포트 섹션별 개수로 도넛 차트 표시
class HomeHabitDistributionSection extends StatelessWidget {
  const HomeHabitDistributionSection({
    super.key,
    required this.questItems,
    required this.isLoading,
    required this.hasError,
    required this.primaryColor,
    required this.gameCardColor,
  });

  final List<HomeQuestItem> questItems;
  final bool isLoading;
  final bool hasError;
  final Color primaryColor;
  final Color gameCardColor;

  static Map<String, int> _bucketCounts(List<HomeQuestItem> items) {
    final m = <String, int>{};
    for (final item in items) {
      final raw = item.sectionKey?.trim();
      final k = (raw == null || raw.isEmpty) ? 'other' : raw;
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || hasError) {
      return const SizedBox.shrink();
    }
    if (questItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final buckets = _bucketCounts(questItems);
    if (buckets.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = buckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: gameCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: primaryColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '영역별 생활습관',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '저장해 둔 모든 습관의 리포트 영역(섹션)별 비율이에요',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    startDegreeOffset: -90,
                    sections: List.generate(entries.length, (i) {
                      final e = entries[i];
                      final c = _sliceColors[i % _sliceColors.length];
                      final pct = total > 0 ? (e.value / total * 100).round() : 0;
                      return PieChartSectionData(
                        value: e.value.toDouble(),
                        color: c,
                        radius: 40,
                        title: '$pct%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
                        ),
                      );
                    }),
                    pieTouchData: PieTouchData(enabled: false),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '총 $total개',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(entries.length, (i) {
                      final e = entries[i];
                      final c = _sliceColors[i % _sliceColors.length];
                      final label = _sectionLabelKo(e.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${e.value}개',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
