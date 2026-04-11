import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/coach_models.dart';
import '../../utils/responsive.dart';

/// 생활습관 도메인 분포 — 기존/추가 후 도넛 차트로 비율 표시
class HabitDomainChartSection extends StatelessWidget {
  const HabitDomainChartSection({
    super.key,
    required this.data,
    this.accentColor = const Color(0xFF37EC13),
  });

  final HabitDomainChartData data;
  final Color accentColor;

  static const _domainColors = {
    'sleep': Color(0xFF7C9EFF),
    'exercise': Color(0xFF4ECDC4),
    'diet': Color(0xFFFFB347),
    'stress': Color(0xFFC792EA),
    'skin': Color(0xFFFF7BAC),
    'smoking': Color(0xFF9EABB8),
    'alcohol': Color(0xFFFF9B7A),
    'uv': Color(0xFFFFE066),
    'other': Color(0xFF9CCC9C),
  };

  static Color _colorFor(String key) =>
      _domainColors[key] ?? const Color(0xFF90A4AE);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allKeys = {...data.before.keys, ...data.after.keys}.toList();

    final cardBg = isDark ? const Color(0xFF151F18) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8EDE8);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1F1A);
    final subtitleColor = isDark ? Colors.white54 : const Color(0xFF6B756F);
    final accent = accentColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.padding(context, 12),
        Responsive.padding(context, 6),
        Responsive.padding(context, 12),
        Responsive.padding(context, 6),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(Responsive.padding(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.14 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.donut_large_rounded,
                      size: Responsive.iconSize(context, 22),
                      color: accent,
                    ),
                  ),
                  SizedBox(width: Responsive.padding(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '생활습관 도메인 분포',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 15),
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                            color: titleColor,
                          ),
                        ),
                        SizedBox(height: Responsive.padding(context, 2)),
                        Text(
                          '영역별 습관 비율을 기존과 비교해 보세요',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 11.5),
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.padding(context, 28)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DomainDonutBlock(
                      label: '기존',
                      counts: data.before,
                      allKeys: allKeys,
                      isDark: isDark,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 6),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: subtitleColor,
                    ),
                  ),
                  Expanded(
                    child: _DomainDonutBlock(
                      label: '추가 후',
                      counts: data.after,
                      allKeys: allKeys,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainDonutBlock extends StatelessWidget {
  const _DomainDonutBlock({
    required this.label,
    required this.counts,
    required this.allKeys,
    required this.isDark,
  });

  final String label;
  final Map<String, int> counts;
  final List<String> allKeys;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final entries = allKeys
        .map((k) => MapEntry(k, counts[k] ?? 0))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final labelMuted =
        isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF8A928C);
    final centerTextColor = isDark ? Colors.white : const Color(0xFF1A1F1A);
    final legendMuted =
        isDark ? Colors.white60 : const Color(0xFF5C6560);

    final chartSize = Responsive.padding(context, 72).clamp(70.0, 88.0);
    // fl_chart: 바깥 반지름 = centerSpaceRadius + section.radius → 합이 chartSize/2 이하여야 함
    // (이전 0.435+0.5)*chartSize 는 0.935*chartSize 로 정사각형 밖으로 그려짐)
    final maxOuter = (chartSize * 0.5) - 2;
    final centerSpaceRadius = maxOuter * (0.435 / 0.935);
    final sectionRingRadius = maxOuter - centerSpaceRadius;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 11),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: labelMuted,
          ),
        ),
        SizedBox(height: Responsive.padding(context, 16)),
        Center(
          child: SizedBox.square(
            dimension: chartSize,
            child: total <= 0
                ? Center(
                    child: Text(
                      '없음',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: legendMuted,
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      PieChart(
                        PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: centerSpaceRadius,
                            startDegreeOffset: -90,
                            sections: List.generate(entries.length, (i) {
                              final e = entries[i];
                              final c = HabitDomainChartSection._colorFor(e.key);
                              return PieChartSectionData(
                                value: e.value.toDouble(),
                                color: c,
                                radius: sectionRingRadius,
                                showTitle: false,
                              );
                            }),
                          pieTouchData: PieTouchData(enabled: false),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 15.5),
                              fontWeight: FontWeight.w800,
                              height: 1,
                              letterSpacing: -0.5,
                              color: centerTextColor,
                            ),
                          ),
                          Text(
                            '습관',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 9),
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                              color: legendMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
