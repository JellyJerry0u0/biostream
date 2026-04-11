import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/habit_service.dart';
import '../../services/habit_quota.dart';

class TodayMeHabitSection extends StatefulWidget {
  const TodayMeHabitSection({
    super.key,
    required this.primaryColor,
  });

  final Color primaryColor;

  @override
  State<TodayMeHabitSection> createState() => _TodayMeHabitSectionState();
}

class _TodayMeHabitSectionState extends State<TodayMeHabitSection> {
  final HabitService _habitService = HabitService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final result = await _habitService.getCheckInsSummary(
      fromDate: '${from.year}-${_pad(from.month)}-${_pad(from.day)}',
      toDate: '${now.year}-${_pad(now.month)}-${_pad(now.day)}',
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _data = result;
      } else {
        _error = result['message'] as String?;
      }
    });
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _quotaSubtitle(int habitCount) {
    final info = _data != null ? HabitQuotaInfo.tryParse(_data!) : null;
    if (info != null) {
      return '최근 30일 · 생활습관 $habitCount/${info.max}개';
    }
    return '최근 30일 · 생활습관 $habitCount개';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE8F0EB)),
          ),
          child: const Center(
            child: SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return const SizedBox.shrink();
    }

    final habits = _data?['habits'] as List<dynamic>? ?? [];
    final byDate = _data?['check_ins_by_date'] as Map<String, dynamic>? ?? {};
    final dateRange = _data?['date_range'] as Map<String, dynamic>? ?? {};

    if (habits.isEmpty) {
      return const SizedBox.shrink();
    }

    var dates = byDate.keys.toList()..sort();
    if (dates.isEmpty) {
      return _buildEmptyState();
    }
    if (dates.length > 14) {
      dates = dates.sublist(dates.length - 14);
    }

    final habitTotal = habits.length;
    final ratioByDate = <String, double>{};
    for (final d in dates) {
      final entries = byDate[d] as List<dynamic>? ?? [];
      final completed = entries.where((e) => e['completed'] == true).length;
      ratioByDate[d] = habitTotal > 0
          ? (100 * completed / habitTotal).round().clamp(0, 100).toDouble()
          : 0.0;
    }

    const chartMaxY = 100.0;
    final barGroups = dates.asMap().entries.map((e) {
      final idx = e.key.toDouble();
      final d = e.value;
      final v = ratioByDate[d] ?? 0.0;
      return BarChartGroupData(
        x: idx.toInt(),
        barRods: [
          BarChartRodData(
            toY: v,
            color: widget.primaryColor,
            width: 12,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final labelIndices = dates.length > 7
        ? <int>{0, dates.length ~/ 3, dates.length * 2 ~/ 3, dates.length - 1}
        : List.generate(dates.length, (i) => i).toSet();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE8F0EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.track_changes,
                  color: widget.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '생활습관 실천 현황',
                  style: TextStyle(
                    color: Color(0xFF102217),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _quotaSubtitle(habits.length),
              style: const TextStyle(
                color: Color(0xFF92A29B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: 0,
                  maxY: chartMaxY + 4,
                  barTouchData: BarTouchData(
                    enabled: false,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= dates.length) {
                            return const SizedBox.shrink();
                          }
                          if (!labelIndices.contains(i)) {
                            return const SizedBox.shrink();
                          }
                          final d = dates[i];
                          final parts = d.split('-');
                          if (parts.length >= 2) {
                            return Text(
                              '${parts[1]}/${parts[2]}',
                              style: const TextStyle(
                                color: Color(0xFF7A8380),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFE9F1EC),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups.isEmpty
                      ? [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: 0,
                                color: Colors.transparent,
                                width: 12,
                              ),
                            ],
                          ),
                        ]
                      : barGroups,
                ),
                swapAnimationDuration: const Duration(milliseconds: 200),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '날짜별 완료 비율(%)',
              style: TextStyle(
                color: widget.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE8F0EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: widget.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '생활습관 실천 현황',
                  style: TextStyle(
                    color: Color(0xFF102217),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '리포트에서 행동을 탭해 생활습관에 담고,\n매일 체크인하면 여기에 기록됩니다.',
              style: TextStyle(
                color: Color(0xFF92A29B),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
