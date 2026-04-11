import 'package:flutter/material.dart';

import '../../models/coach_models.dart';
import '../../utils/responsive.dart';
import 'coach_chat_shell_colors.dart';

/// 코치가 제안한 목표 조정 — 동의/거절 (다중 제안 지원)
class CoachGoalProposalsBar extends StatelessWidget {
  const CoachGoalProposalsBar({
    super.key,
    required this.isDark,
    required this.engine,
    required this.horizontalPadding,
    required this.proposals,
    required this.isSubmitting,
    required this.onAccept,
    required this.onDecline,
  });

  final bool isDark;
  final CoachEngine engine;
  final double horizontalPadding;
  final List<GoalProposalItem> proposals;
  final bool isSubmitting;
  final void Function(GoalProposalItem item) onAccept;
  final void Function(GoalProposalItem item) onDecline;

  @override
  Widget build(BuildContext context) {
    if (proposals.isEmpty) {
      return const SizedBox.shrink();
    }

    final accent = CoachChatShellColors.accent(engine);
    final accentFg = CoachChatShellColors.onAccentFg(engine);
    final cardBg = CoachChatShellColors.habitPersonalizationCardBg(
      isDark: isDark,
      engine: engine,
    );
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE4EAE4);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.05),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.padding(context, 16),
                  Responsive.padding(context, 14),
                  Responsive.padding(context, 16),
                  Responsive.padding(context, 6),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: isDark ? 0.22 : 0.18),
                            accent.withValues(alpha: isDark ? 0.08 : 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.track_changes_rounded,
                        size: Responsive.iconSize(context, 20),
                        color: accent,
                      ),
                    ),
                    SizedBox(width: Responsive.padding(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '목표 조정 제안',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 15),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                              color: isDark ? Colors.white : accentFg,
                            ),
                          ),
                          if (proposals.length > 1)
                            Text(
                              '${proposals.length}건 · 하나씩 확인해 주세요',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 11.5),
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF6B756F),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.padding(context, 14),
                  0,
                  Responsive.padding(context, 14),
                  Responsive.padding(context, 14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < proposals.length; i++) ...[
                      if (i > 0)
                        SizedBox(height: Responsive.padding(context, 12)),
                      _ProposalTile(
                        isDark: isDark,
                        engine: engine,
                        accent: accent,
                        accentFg: accentFg,
                        index: i,
                        total: proposals.length,
                        proposal: proposals[i],
                        isSubmitting: isSubmitting,
                        onAccept: onAccept,
                        onDecline: onDecline,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.isDark,
    required this.engine,
    required this.accent,
    required this.accentFg,
    required this.index,
    required this.total,
    required this.proposal,
    required this.isSubmitting,
    required this.onAccept,
    required this.onDecline,
  });

  final bool isDark;
  final CoachEngine engine;
  final Color accent;
  final Color accentFg;
  final int index;
  final int total;
  final GoalProposalItem proposal;
  final bool isSubmitting;
  final void Function(GoalProposalItem item) onAccept;
  final void Function(GoalProposalItem item) onDecline;

  @override
  Widget build(BuildContext context) {
    final innerBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : CoachChatShellColors.habitTileStrokeLight(engine);
    final bodyColor = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : accentFg;
    final dimColor = isDark ? Colors.white54 : const Color(0xFF6B756F);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: innerBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stroke),
      ),
      child: Padding(
        padding: EdgeInsets.all(Responsive.padding(context, 14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (total > 1)
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.padding(context, 10)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 8),
                    vertical: Responsive.padding(context, 4),
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.14 : 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${index + 1} / $total',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 10.5),
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            Text(
              '제안 목표',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 10),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: dimColor,
              ),
            ),
            SizedBox(height: Responsive.padding(context, 6)),
            Text(
              proposal.proposedTarget,
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                height: 1.4,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.25,
                color: bodyColor,
              ),
            ),
            if (proposal.reason.isNotEmpty) ...[
              SizedBox(height: Responsive.padding(context, 12)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 12),
                  vertical: Responsive.padding(context, 10),
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : CoachChatShellColors.habitReasonBgLight(engine),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(
                      color: accent.withValues(alpha: 0.55),
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  proposal.reason,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: dimColor,
                  ),
                ),
              ),
            ],
            SizedBox(height: Responsive.padding(context, 14)),
            Row(
              children: [
                Expanded(
                  child: _SecondaryGoalButton(
                    isDark: isDark,
                    accentFg: accentFg,
                    label: '유지할게요',
                    onPressed:
                        isSubmitting ? null : () => onDecline(proposal),
                  ),
                ),
                SizedBox(width: Responsive.padding(context, 10)),
                Expanded(
                  child: _PrimaryGoalButton(
                    accent: accent,
                    accentFg: accentFg,
                    label: '이대로 반영',
                    isSubmitting: isSubmitting,
                    onPressed:
                        isSubmitting ? null : () => onAccept(proposal),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryGoalButton extends StatelessWidget {
  const _PrimaryGoalButton({
    required this.accent,
    required this.accentFg,
    required this.label,
    required this.isSubmitting,
    required this.onPressed,
  });

  final Color accent;
  final Color accentFg;
  final String label;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Responsive.fontSize(context, 48),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentFg,
          elevation: 0,
          shadowColor: accent.withValues(alpha: 0.35),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ).copyWith(
          elevation: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return 0.0;
            return 1.5;
          }),
        ),
        child: isSubmitting
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: accentFg,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }
}

class _SecondaryGoalButton extends StatelessWidget {
  const _SecondaryGoalButton({
    required this.isDark,
    required this.accentFg,
    required this.label,
    required this.onPressed,
  });

  final bool isDark;
  final Color accentFg;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFD5DCD5);
    final fg = isDark ? Colors.white.withValues(alpha: 0.9) : accentFg;

    return SizedBox(
      height: Responsive.fontSize(context, 48),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: border, width: 1.2),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 10),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 13.5),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.15,
          ),
        ),
      ),
    );
  }
}
