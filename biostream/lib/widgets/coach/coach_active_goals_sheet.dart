import 'package:flutter/material.dart';

import '../../services/coach_goals_service.dart';
import '../../utils/responsive.dart';
import 'coach_chat_shell_colors.dart';
import '../../models/coach_models.dart';

String coachGoalDomainLabelKo(String domain) {
  switch (domain) {
    case 'sleep':
      return '수면';
    case 'exercise':
      return '운동';
    case 'uv_protection':
      return '자외선·야외';
    case 'alcohol':
      return '음주';
    case 'smoking':
      return '흡연';
    case 'stress':
      return '스트레스';
    case 'skin_routine':
      return '피부 루틴';
    default:
      return '기타';
  }
}

/// 코치 모드 상단에서 열리는 «적응형 목표» 바텀시트
Future<void> showCoachActiveGoalsSheet({
  required BuildContext context,
  required bool isDark,
  required CoachEngine engine,
}) async {
  final accent = CoachChatShellColors.accent(engine);
  final accentFg = CoachChatShellColors.onAccentFg(engine);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.52,
        minChildSize: 0.32,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return _CoachGoalsSheetBody(
            scrollController: scrollController,
            isDark: isDark,
            accent: accent,
            accentFg: accentFg,
          );
        },
      );
    },
  );
}

class _CoachGoalsSheetBody extends StatefulWidget {
  const _CoachGoalsSheetBody({
    required this.scrollController,
    required this.isDark,
    required this.accent,
    required this.accentFg,
  });

  final ScrollController scrollController;
  final bool isDark;
  final Color accent;
  final Color accentFg;

  @override
  State<_CoachGoalsSheetBody> createState() => _CoachGoalsSheetBodyState();
}

class _CoachGoalsSheetBodyState extends State<_CoachGoalsSheetBody> {
  late Future<List<CoachActiveGoalItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = CoachGoalsService.instance.fetchActiveGoals();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1C1A24) : Colors.white;
    final fg = widget.isDark ? Colors.white : const Color(0xFF1A1628);
    final sub = widget.isDark ? Colors.white60 : const Color(0xFF6B756F);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white24
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Responsive.padding(context, 20),
              Responsive.padding(context, 16),
              Responsive.padding(context, 20),
              Responsive.padding(context, 6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(
                          alpha: widget.isDark ? 0.2 : 0.14,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.track_changes_rounded,
                        color: widget.accent,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: Responsive.padding(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '코치 목표',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 18),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: fg,
                            ),
                          ),
                          Text(
                            '코치가 대화·기록을 바탕으로 잡는 목표예요. 리포트에서 고른 생활습관 카드와는 따로 관리돼요.',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 11.5),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CoachActiveGoalItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: widget.accent,
                      ),
                    ),
                  );
                }
                final goals = snap.data ?? [];
                if (goals.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 24),
                    ),
                    child: Center(
                      child: Text(
                        '아직 저장된 코치 목표가 없어요.\n코치 모드에서 이야기를 나누면 목표가 쌓여요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 14),
                          height: 1.45,
                          color: sub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  padding: EdgeInsets.fromLTRB(
                    Responsive.padding(context, 16),
                    0,
                    Responsive.padding(context, 16),
                    Responsive.padding(context, 20),
                  ),
                  itemCount: goals.length,
                  itemBuilder: (context, i) {
                    final g = goals[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: Responsive.padding(context, 12),
                      ),
                      child: _GoalCard(
                        isDark: widget.isDark,
                        accent: widget.accent,
                        accentFg: widget.accentFg,
                        goal: g,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.isDark,
    required this.accent,
    required this.accentFg,
    required this.goal,
  });

  final bool isDark;
  final Color accent;
  final Color accentFg;
  final CoachActiveGoalItem goal;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF7F5FC);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : accent.withValues(alpha: 0.12);
    final titleColor = isDark ? Colors.white : accentFg;
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF4A4558);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: EdgeInsets.all(Responsive.padding(context, 14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 8),
                    vertical: Responsive.padding(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    coachGoalDomainLabelKo(goal.domain),
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 11),
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                if (goal.pendingUserApproval) ...[
                  SizedBox(width: Responsive.padding(context, 8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 6),
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '조정 제안 대기',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 9.5),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (goal.description.isNotEmpty) ...[
              SizedBox(height: Responsive.padding(context, 10)),
              Text(
                goal.description,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12.5),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ],
            SizedBox(height: Responsive.padding(context, 8)),
            Text(
              '현재 목표',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 10),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: bodyColor.withValues(alpha: 0.85),
              ),
            ),
            SizedBox(height: Responsive.padding(context, 4)),
            Text(
              goal.currentTarget.isNotEmpty
                  ? goal.currentTarget
                  : '(문구 없음)',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                height: 1.35,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: titleColor,
              ),
            ),
            if (goal.proposedTarget != null &&
                goal.proposedTarget!.trim().isNotEmpty) ...[
              SizedBox(height: Responsive.padding(context, 10)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(Responsive.padding(context, 10)),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: accent.withValues(alpha: 0.55), width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '제안된 조정',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 10),
                        fontWeight: FontWeight.w700,
                        color: bodyColor,
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 4)),
                    Text(
                      goal.proposedTarget!,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12.5),
                        height: 1.4,
                        color: bodyColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (goal.successRate7d != null) ...[
              SizedBox(height: Responsive.padding(context, 8)),
              Text(
                '최근 7일 달성률 ${(goal.successRate7d! * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 11),
                  fontWeight: FontWeight.w600,
                  color: bodyColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
