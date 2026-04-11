import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

/// 리포트 저장 시 등록될 생활습관(등록 예정). 기본은 접힘, 개수만 표시.
class ResultThisWeekHabitsSection extends StatefulWidget {
  final bool isDark;
  final List<Map<String, String>> habits; // [{title, detail, sectionKey}]
  final void Function(String title) onRemove;
  /// null이면 한도 정보 숨김
  final int? habitQuestMax;
  final int habitActiveOnServer;

  const ResultThisWeekHabitsSection({
    super.key,
    required this.isDark,
    required this.habits,
    required this.onRemove,
    this.habitQuestMax,
    this.habitActiveOnServer = 0,
  });

  @override
  State<ResultThisWeekHabitsSection> createState() =>
      _ResultThisWeekHabitsSectionState();
}

class _ResultThisWeekHabitsSectionState
    extends State<ResultThisWeekHabitsSection> {
  bool _expanded = false;

  String? get _quotaLine {
    final cap = widget.habitQuestMax;
    if (cap == null) return null;
    final used = widget.habitActiveOnServer + widget.habits.length;
    return '저장 한도 $used / $cap · 리포트 저장 시 생활습관으로 등록';
  }

  @override
  void didUpdateWidget(covariant ResultThisWeekHabitsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.habits.isEmpty) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final habits = widget.habits;

    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 20)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2C17) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_circle_outlined,
                size: Responsive.iconSize(context, 20),
                color: const Color(0xFF37EC13),
              ),
              SizedBox(width: Responsive.padding(context, 8)),
              Text(
                '오늘의 생활습관',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          if (_quotaLine != null) ...[
            SizedBox(height: Responsive.padding(context, 6)),
            Text(
              _quotaLine!,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 11),
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
          SizedBox(height: Responsive.padding(context, 12)),
          if (habits.isEmpty)
            Padding(
              padding:
                  EdgeInsets.symmetric(vertical: Responsive.padding(context, 16)),
              child: Text(
                '행동 항목을 탭하면 등록 예정 생활습관에 넣을 수 있어요.\n리포트 저장 시 홈의 오늘의 생활습관으로 등록됩니다.',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
            )
          else ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 14),
                    vertical: Responsive.padding(context, 12),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF37EC13).withValues(alpha: isDark ? 0.12 : 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF37EC13).withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: Responsive.iconSize(context, 20),
                        color: const Color(0xFF37EC13),
                      ),
                      SizedBox(width: Responsive.padding(context, 10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '등록 예정 생활습관',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 13),
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: Responsive.padding(context, 2)),
                            Text(
                              '${habits.length}개',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 16),
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        size: Responsive.iconSize(context, 26),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: Responsive.padding(context, 10)),
                        ...habits.asMap().entries.map((entry) {
                          final i = entry.key;
                          final h = entry.value;
                          final title = h['title'] ?? '';
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: i < habits.length - 1
                                  ? Responsive.padding(context, 8)
                                  : 0,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => widget.onRemove(title),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(
                                      Responsive.padding(context, 12)),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF37EC13)
                                        .withValues(alpha: isDark ? 0.1 : 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF37EC13)
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: Responsive.iconSize(context, 18),
                                        color: const Color(0xFF37EC13),
                                      ),
                                      SizedBox(
                                          width: Responsive.padding(context, 10)),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize:
                                                Responsive.fontSize(context, 14),
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.close,
                                        size: Responsive.iconSize(context, 18),
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}
