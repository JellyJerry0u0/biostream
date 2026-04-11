import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../screens/today_me/today_me_models.dart';

bool _sameCalendarDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

LifestyleHistoryDay? _dayAt(List<LifestyleHistoryDay> history, DateTime d) {
  for (final h in history) {
    if (_sameCalendarDate(h.date, d)) return h;
  }
  return null;
}

double? _uvToChartY(String? v) {
  if (v == null || v.isEmpty) return null;
  switch (v) {
    case '<30m':
      return 1;
    case '30~60':
      return 2;
    case '1~2h':
      return 3;
    case '>2h':
      return 4;
    default:
      return null;
  }
}

/// 달력상 해당 일의 주간 시작(월요일 00:00, 로컬).
DateTime _mondayOfCalendarDay(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// 월요일 기준 `N월 M주차` (같은 달 안에서의 주차).
String _koreanMonthWeekTag(DateTime weekMonday) {
  final wn = ((weekMonday.day - 1) ~/ 7) + 1;
  return '${weekMonday.month}월 $wn주차';
}

String _koreanWeekPageTitle(DateTime weekMonday) {
  final wn = ((weekMonday.day - 1) ~/ 7) + 1;
  return '${weekMonday.year}년 ${weekMonday.month}월 $wn주차';
}

String _shortDateRangeSameMonth(DateTime weekMonday) {
  final sun = weekMonday.add(const Duration(days: 6));
  if (weekMonday.month == sun.month && weekMonday.year == sun.year) {
    return '${weekMonday.month}/${weekMonday.day}–${sun.day}';
  }
  String p(DateTime x) => '${x.month}/${x.day}';
  return '${p(weekMonday)}–${p(sun)}';
}

const List<String> _weekdayLabelsEn = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

bool _weekListContains(Iterable<DateTime> weeks, DateTime monday) {
  final n = _normalizeDate(monday);
  for (final w in weeks) {
    if (_normalizeDate(w) == n) return true;
  }
  return false;
}

bool _dayRowHasChartData(LifestyleHistoryDay h) {
  if (h.sleepMinutes != null && h.sleepMinutes! > 0) return true;
  if (h.sleepQualityScore != null) return true;
  if (h.stressScore != null) return true;
  final dr = h.drinkingDaysPerWeek;
  if (dr != null && dr.isNotEmpty && dr != '-') return true;
  if ((h.aerobicSessions30min ?? 0) > 0 || (h.resistanceSessions30min ?? 0) > 0) {
    return true;
  }
  final uv = h.uvOutdoor10to16;
  if (uv != null && uv.isNotEmpty && uv != '-') return true;
  if (h.sunscreenApplied != null) return true;
  final sm = h.smokingStatus;
  if (sm != null && sm.isNotEmpty && sm != '-') return true;
  return false;
}

/// 그래프에 쓸 값이 하루라도 있는 주의 월요일들, 최신순.
List<DateTime> _weeksWithDataMondays(List<LifestyleHistoryDay> history) {
  final seen = <int>{};
  final out = <DateTime>[];
  for (final h in history) {
    if (!_dayRowHasChartData(h)) continue;
    final m = _mondayOfCalendarDay(h.date);
    final stamp = m.year * 10000 + m.month * 100 + m.day;
    if (seen.add(stamp)) {
      out.add(_normalizeDate(m));
    }
  }
  out.sort((a, b) => b.compareTo(a));
  return out;
}

DateTime _defaultWeekMonday(List<DateTime> weeks, DateTime todayMonday) {
  if (weeks.isEmpty) return _normalizeDate(todayMonday);
  final cap = _normalizeDate(todayMonday);
  DateTime? best;
  for (final w in weeks) {
    final wm = _normalizeDate(w);
    if (!wm.isAfter(cap)) {
      if (best == null || wm.isAfter(best)) best = wm;
    }
  }
  return best ?? weeks.first;
}

int _mondayValueKey(DateTime m) {
  final d = _normalizeDate(m);
  return d.year * 10000 + d.month * 100 + d.day;
}

/// `true` 금주, `false` 음주 등 기록됨, `null` 그날 스냅샷 없음·판단 불가
bool? _abstainStateForDay(LifestyleHistoryDay? d) {
  if (d == null) return null;
  final raw = d.drinkingDaysPerWeek;
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty || s == '-') return null;
  if (s == '0') return true;
  return false;
}

/// `true` 금연(비흡연), `false` 흡연 기록, `null` 미기록
bool? _nonSmokingStateForDay(LifestyleHistoryDay? d) {
  if (d == null) return null;
  final s = d.smokingStatus?.trim();
  if (s == null || s.isEmpty || s == '-') return null;
  final low = s.toLowerCase();
  if (low == 'current' || s.contains('현재')) return false;
  return true;
}

/// `true` 도포 O, `false` 도포 X 기록, `null` 미기록
bool? _sunscreenYesStateForDay(LifestyleHistoryDay? d) {
  if (d == null) return null;
  if (d.sunscreenApplied == null) return null;
  return d.sunscreenApplied == true;
}

class TodayMeLifestyleChartsSection extends StatefulWidget {
  const TodayMeLifestyleChartsSection({
    super.key,
    required this.history,
    required this.primaryColor,
  });

  final List<LifestyleHistoryDay> history;
  final Color primaryColor;

  @override
  State<TodayMeLifestyleChartsSection> createState() =>
      _TodayMeLifestyleChartsSectionState();
}

class _TodayMeLifestyleChartsSectionState extends State<TodayMeLifestyleChartsSection> {
  /// 사용자가 시트에서 고른 주(월요일). 없으면 기본 규칙으로 표시.
  DateTime? _pickedWeekMonday;

  @override
  void didUpdateWidget(covariant TodayMeLifestyleChartsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dataWeeks = _weeksWithDataMondays(widget.history);
    if (_pickedWeekMonday != null &&
        !_weekListContains(dataWeeks, _pickedWeekMonday!)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pickedWeekMonday = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE8F0EB)),
          ),
          child: const Text(
            '아직 저장된 일별 기록이 없어요. 생활을 기록하고 자정이 지나면 그래프로 모아 볼 수 있어요.',
            style: TextStyle(
              color: Color(0xFF7A8380),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final thisMonday = _mondayOfCalendarDay(todayDay);
    final dataWeeks = _weeksWithDataMondays(widget.history);

    final displayMonday = _pickedWeekMonday != null &&
            _weekListContains(dataWeeks, _pickedWeekMonday!)
        ? _normalizeDate(_pickedWeekMonday!)
        : _defaultWeekMonday(dataWeeks, thisMonday);

    final slots = List<LifestyleHistoryDay?>.generate(
      7,
      (i) => _dayAt(
        widget.history,
        displayMonday.add(Duration(days: i)),
      ),
    );
    final monthWeek = _koreanMonthWeekTag(displayMonday);
    final isThisWeek =
        _normalizeDate(displayMonday) == _normalizeDate(thisMonday);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Dashboard',
            style: TextStyle(
              color: Color(0xFF102217),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dataWeeks.isEmpty
                ? '오늘의 생활습관을 기록해주세요.'
                : '아래 날짜를 눌러 기록이 있는 주를 고를 수 있어요',
            style: const TextStyle(
              color: Color(0xFF92A29B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _WeekSelectorBar(
            title: isThisWeek
                ? '이번 주 · ${_koreanWeekPageTitle(displayMonday)}'
                : _koreanWeekPageTitle(displayMonday),
            rangeLine: '${_shortDateRangeSameMonth(displayMonday)} · Mon–Sun',
            primaryColor: widget.primaryColor,
            enabled: dataWeeks.isNotEmpty,
            onTap: dataWeeks.isEmpty ? null : () => _openWeekPicker(context, dataWeeks, displayMonday),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.028),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_mondayValueKey(displayMonday)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SleepChartsCard(
                    labels: _weekdayLabelsEn,
                    slots: slots,
                    primaryColor: widget.primaryColor,
                    sleepCardTitle: '수면 ($monthWeek)',
                  ),
                  const SizedBox(height: 12),
                  _ExerciseBarCard(
                    labels: _weekdayLabelsEn,
                    slots: slots,
                    primaryColor: widget.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  _LineMetricCard(
                    title: '스트레스',
                    unit: '/10',
                    labels: _weekdayLabelsEn,
                    slots: slots,
                    primaryColor: widget.primaryColor,
                    value: (d) => d.stressScore,
                    minY: 0,
                    maxY: 10,
                  ),
                  const SizedBox(height: 12),
                  _BinaryWeekHabitCard(
                    title: '음주',
                    subtitle: '금주 : 체크 / 음주 : 밝은 회색',
                    labels: _weekdayLabelsEn,
                    slots: slots,
                    fillColor: widget.primaryColor,
                    stateAt: _abstainStateForDay,
                  ),
                  const SizedBox(height: 12),
                  _BinaryWeekHabitCard(
                    title: '흡연',
                    subtitle: '금연 : 체크 / 흡연 : 밝은 회색',
                    labels: _weekdayLabelsEn,
                    slots: slots,
                    fillColor: const Color(0xFF5B8DEF),
                    stateAt: _nonSmokingStateForDay,
                  ),
                  const SizedBox(height: 12),
                  _BinaryWeekHabitCard(
                    title: '선크림',
                    subtitle: '도포 : 체크 / 도포X : 밝은 회색',
                    labels: _weekdayLabelsEn,
                    slots: slots,
                    fillColor: const Color(0xFFFFB74D),
                    stateAt: _sunscreenYesStateForDay,
                  ),
                  const SizedBox(height: 12),
                  _UvOutdoorOnlyCard(
                    labels: _weekdayLabelsEn,
                    slots: slots,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWeekPicker(
    BuildContext context,
    List<DateTime> dataWeeks,
    DateTime currentMonday,
  ) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WeekPickerSheet(
        weeks: dataWeeks,
        selectedMonday: currentMonday,
        primaryColor: widget.primaryColor,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _pickedWeekMonday = _normalizeDate(picked);
      });
    }
  }
}

class _WeekSelectorBar extends StatelessWidget {
  const _WeekSelectorBar({
    required this.title,
    required this.rangeLine,
    required this.primaryColor,
    required this.enabled,
    this.onTap,
  });

  final String title;
  final String rangeLine;
  final Color primaryColor;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF4F8F5) : const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFD8E8DF)
                  : const Color(0xFFE8F0EB),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled
                              ? const Color(0xFF102217)
                              : const Color(0xFF92A29B),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rangeLine,
                        style: const TextStyle(
                          color: Color(0xFF92A29B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: enabled
                      ? primaryColor.withValues(alpha: 0.9)
                      : const Color(0xFFB8C4BE),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekPickerSheet extends StatelessWidget {
  const _WeekPickerSheet({
    required this.weeks,
    required this.selectedMonday,
    required this.primaryColor,
  });

  final List<DateTime> weeks;
  final DateTime selectedMonday;
  final Color primaryColor;

  List<Widget> _buildListTiles(BuildContext context) {
    final children = <Widget>[];
    String? prevYm;
    for (final w in weeks) {
      final ym = '${w.year}년 ${w.month}월';
      if (ym != prevYm) {
        prevYm = ym;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              ym,
              style: TextStyle(
                color: primaryColor.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }
      final sel = _normalizeDate(w) == _normalizeDate(selectedMonday);
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: sel ? const Color(0xFFEEF6F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).pop(w),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_koreanMonthWeekTag(w)} · ${_shortDateRangeSameMonth(w)}',
                        style: const TextStyle(
                          color: Color(0xFF102217),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (sel)
                      Icon(Icons.check_circle_rounded, color: primaryColor, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.58;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E8E3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '기록이 있는 주 선택',
                    style: TextStyle(
                      color: Color(0xFF102217),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '년·월별로 묶었어요. 항목을 누르면 그 주 그래프로 바뀌어요.',
                    style: TextStyle(
                      color: Color(0xFF92A29B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: maxH,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, bottom + 12),
                  children: _buildListTiles(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BinaryWeekHabitCard extends StatelessWidget {
  const _BinaryWeekHabitCard({
    required this.title,
    required this.subtitle,
    required this.labels,
    required this.slots,
    required this.fillColor,
    required this.stateAt,
  });

  final String title;
  final String subtitle;
  final List<String> labels;
  final List<LifestyleHistoryDay?> slots;
  final Color fillColor;
  final bool? Function(LifestyleHistoryDay? d) stateAt;

  @override
  Widget build(BuildContext context) {
    var anyKnown = false;
    for (final s in slots) {
      if (stateAt(s) != null) {
        anyKnown = true;
        break;
      }
    }
    if (!anyKnown) {
      return _ChartCardShell(
        title: title,
        subtitle: '이 기간에 기록이 없어요',
        child: const SizedBox(height: 8),
      );
    }

    return _ChartCardShell(
      title: title,
      subtitle: subtitle,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(7, (i) {
            final d = i < slots.length ? slots[i] : null;
            final t = stateAt(d);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: t == true
                              ? fillColor
                              : t == false
                                  ? const Color(0xFFEEF1EF)
                                  : Colors.transparent,
                          border: Border.all(
                            color: t == null
                                ? const Color(0xFFC5D1CA)
                                : const Color(0xFFD8E3DD),
                            width: t == null ? 1.2 : 1,
                          ),
                        ),
                        child: t == true
                            ? Center(
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Colors.white.withValues(alpha: 0.96),
                                  size: 22,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i < labels.length ? labels[i] : '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7A8380),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ChartCardShell extends StatelessWidget {
  const _ChartCardShell({
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8F0EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF102217),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF92A29B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }
}

SideTitles _bottomTitles(List<String> labels, {int maxLabels = 5}) {
  final step = labels.length <= 7
      ? 1
      : (labels.length / maxLabels).ceil().clamp(1, labels.length);
  return SideTitles(
    showTitles: true,
    reservedSize: 26,
    interval: 1,
    getTitlesWidget: (value, meta) {
      final i = value.toInt();
      if (i < 0 || i >= labels.length) return const SizedBox.shrink();
      if (i != 0 && i != labels.length - 1 && i % step != 0) {
        return const SizedBox.shrink();
      }
      return Text(
        labels[i],
        style: const TextStyle(
          color: Color(0xFF7A8380),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
    },
  );
}

FlGridData _grid() {
  return FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: null,
    getDrawingHorizontalLine: (value) => const FlLine(
      color: Color(0xFFE9F1EC),
      strokeWidth: 1,
    ),
  );
}

class _SleepChartsCard extends StatelessWidget {
  const _SleepChartsCard({
    required this.labels,
    required this.slots,
    required this.primaryColor,
    required this.sleepCardTitle,
  });

  final List<String> labels;
  final List<LifestyleHistoryDay?> slots;
  final Color primaryColor;
  /// 예: `수면 (3월 2주차)`
  final String sleepCardTitle;

  @override
  Widget build(BuildContext context) {
    final hoursSpots = <FlSpot>[];
    final qualitySpots = <FlSpot>[];
    for (var i = 0; i < slots.length; i++) {
      final d = slots[i];
      if (d == null) continue;
      if (d.sleepMinutes != null && d.sleepMinutes! > 0) {
        hoursSpots.add(FlSpot(i.toDouble(), d.sleepMinutes! / 60.0));
      }
      if (d.sleepQualityScore != null) {
        qualitySpots.add(FlSpot(i.toDouble(), d.sleepQualityScore!));
      }
    }

    if (hoursSpots.isEmpty && qualitySpots.isEmpty) {
      return _ChartCardShell(
        title: sleepCardTitle,
        subtitle: '이 기간에 기록된 수면 데이터가 없어요',
        child: const SizedBox(
          height: 40,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '—',
              style: TextStyle(color: Color(0xFFB8C4BE), fontSize: 22),
            ),
          ),
        ),
      );
    }

    return _ChartCardShell(
      title: sleepCardTitle,
      subtitle: '수면 시간 · 수면의 질',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hoursSpots.isNotEmpty) ...[
            const Text(
              '수면 시간 (시간)',
              style: TextStyle(
                color: Color(0xFF7A8380),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(
              height: 120,
              child: _MiniLineChart(
                spots: hoursSpots,
                labels: labels,
                color: primaryColor,
                minY: 0,
                maxYFromData: true,
                pad: 1.2,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (qualitySpots.isNotEmpty) ...[
            const Text(
              '수면의 질 (/10)',
              style: TextStyle(
                color: Color(0xFF7A8380),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(
              height: 120,
              child: _MiniLineChart(
                spots: qualitySpots,
                labels: labels,
                color: const Color(0xFF5B8DEF),
                minY: 0,
                maxY: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({
    required this.spots,
    required this.labels,
    required this.color,
    this.minY,
    this.maxY,
    this.maxYFromData = false,
    this.pad = 1.0,
  });

  final List<FlSpot> spots;
  final List<String> labels;
  final Color color;
  final double? minY;
  final double? maxY;
  final bool maxYFromData;
  final double pad;

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }
    double minV = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxV = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxYFromData) {
      minV = minY ?? 0;
      maxV = maxV + pad;
      if (maxV <= minV) maxV = minV + 1;
    } else {
      minV = minY ?? minV;
      maxV = maxY ?? maxV + pad;
      if (maxV <= minV) maxV = minV + 1;
    }

    return LineChart(
      LineChartData(
        minY: minV,
        maxY: maxV,
        gridData: _grid(),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(sideTitles: _bottomTitles(labels)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 2.6,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeColor: Colors.white,
                strokeWidth: 1.2,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineMetricCard extends StatelessWidget {
  const _LineMetricCard({
    required this.title,
    required this.unit,
    required this.labels,
    required this.slots,
    required this.primaryColor,
    required this.value,
    this.minY,
    this.maxY,
  });

  final String title;
  final String unit;
  final List<String> labels;
  final List<LifestyleHistoryDay?> slots;
  final Color primaryColor;
  final double? Function(LifestyleHistoryDay d) value;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < slots.length; i++) {
      final d = slots[i];
      if (d == null) continue;
      final v = value(d);
      if (v == null) continue;
      spots.add(FlSpot(i.toDouble(), v));
    }

    if (spots.isEmpty) {
      return _ChartCardShell(
        title: title,
        subtitle: '이 기간에 기록이 없어요',
        child: const SizedBox(height: 8),
      );
    }

    double minV = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxV = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    double lo = minY ?? 0;
    double hi = maxY ?? (maxV + (maxV - minV) * 0.2 + 0.01);
    if (hi <= lo) hi = lo + 1;

    return _ChartCardShell(
      title: title,
      subtitle: unit,
      child: SizedBox(
        height: 140,
        child: LineChart(
          LineChartData(
            minY: lo,
            maxY: hi,
            gridData: _grid(),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(sideTitles: _bottomTitles(labels)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.22,
                color: primaryColor,
                barWidth: 2.8,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 3.2,
                    color: primaryColor,
                    strokeColor: Colors.white,
                    strokeWidth: 1.2,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: primaryColor.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseBarCard extends StatelessWidget {
  const _ExerciseBarCard({
    required this.labels,
    required this.slots,
    required this.primaryColor,
  });

  final List<String> labels;
  final List<LifestyleHistoryDay?> slots;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final groups = <BarChartGroupData>[];
    var peakY = 1.0;
    for (var i = 0; i < slots.length; i++) {
      final d = slots[i];
      final a = d?.aerobicSessions30min;
      final r = d?.resistanceSessions30min;
      if (a == null && r == null) continue;
      final av = (a ?? 0).toDouble();
      final rv = (r ?? 0).toDouble();
      if (av <= 0 && rv <= 0) continue;
      peakY = [peakY, av, rv].reduce((x, y) => x > y ? x : y);
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: [
            BarChartRodData(
              toY: av,
              width: 7,
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: rv,
              width: 7,
              color: const Color(0xFF5B8DEF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    if (groups.isEmpty) {
      return _ChartCardShell(
        title: '운동',
        subtitle: '유산소·근력 (30분+ 세션)',
        child: const Text(
          '이 기간에 운동 회수 기록이 없어요',
          style: TextStyle(
            color: Color(0xFF92A29B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final chartMaxY = (peakY * 1.15).clamp(2.0, double.infinity);

    return _ChartCardShell(
      title: '운동',
      subtitle: '막대: 유산소(초록) · 근력(파랑), 30분+ 기준 회수',
      footer: Row(
        children: [
          _legendDot(primaryColor, '유산소'),
          const SizedBox(width: 12),
          _legendDot(const Color(0xFF5B8DEF), '근력'),
        ],
      ),
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: chartMaxY,
            gridData: _grid(),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(sideTitles: _bottomTitles(labels)),
            ),
            barGroups: groups,
          ),
        ),
      ),
    );
  }
}

Widget _legendDot(Color c, String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7A8380),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _UvOutdoorOnlyCard extends StatelessWidget {
  const _UvOutdoorOnlyCard({
    required this.labels,
    required this.slots,
  });

  final List<String> labels;
  final List<LifestyleHistoryDay?> slots;

  @override
  Widget build(BuildContext context) {
    final uvGroups = <BarChartGroupData>[];
    for (var i = 0; i < slots.length; i++) {
      final d = slots[i];
      if (d == null) continue;
      final uv = _uvToChartY(d.uvOutdoor10to16);
      if (uv != null) {
        uvGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: uv,
                width: 10,
                color: const Color(0xFFFFB74D),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          ),
        );
      }
    }

    if (uvGroups.isEmpty) {
      return _ChartCardShell(
        title: '코어시간 외출',
        subtitle: '이 기간에 기록이 없어요',
        child: const SizedBox(height: 8),
      );
    }

    return _ChartCardShell(
      title: '코어시간 외출',
      subtitle: '막대 높을수록 코어시간대 외출이 길었어요',
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            maxY: 4,
            gridData: _grid(),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(sideTitles: _bottomTitles(labels)),
            ),
            barGroups: uvGroups,
          ),
        ),
      ),
    );
  }
}
