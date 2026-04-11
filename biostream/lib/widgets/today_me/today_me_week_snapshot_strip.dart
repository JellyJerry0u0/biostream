import 'package:flutter/material.dart';

/// 이번 주(월~일) 서버 스냅샷 유무를 7칸으로 표시. 스냅샷 없는 과거·오늘만 [onEmptyDayTap].
class TodayMeWeekSnapshotStrip extends StatelessWidget {
  const TodayMeWeekSnapshotStrip({
    super.key,
    required this.primaryColor,
    required this.savedSnapshotDateKeys,
    required this.onEmptyDayTap,
  });

  final Color primaryColor;
  final Set<String> savedSnapshotDateKeys;
  final ValueChanged<DateTime> onEmptyDayTap;

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _mondayOf(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return x.subtract(Duration(days: x.weekday - DateTime.monday));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final monday = _mondayOf(todayNorm);
    const labels = ['월', '화', '수', '목', '금', '토', '일'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 기록',
            style: TextStyle(
              color: const Color(0xFF102217).withValues(alpha: 0.88),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              final key = _dateKey(day);
              final hasSnap = savedSnapshotDateKeys.contains(key);
              final isFuture = day.isAfter(todayNorm);
              final canTapEmpty = !hasSnap && !isFuture;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                  child: Column(
                    children: [
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isFuture
                              ? const Color(0xFFB8C4BE)
                              : const Color(0xFF7A8380),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isFuture
                              ? const Color(0xFFB8C4BE)
                              : const Color(0xFF102217),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: canTapEmpty
                              ? () => onEmptyDayTap(
                                    DateTime(day.year, day.month, day.day),
                                  )
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: hasSnap
                                    ? primaryColor.withValues(alpha: 0.92)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: hasSnap
                                      ? primaryColor.withValues(alpha: 0.35)
                                      : const Color(0xFFD5DED8),
                                  width: hasSnap ? 0 : 1.2,
                                ),
                              ),
                              child: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
