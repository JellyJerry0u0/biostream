import 'package:flutter/material.dart';

import '../../models/coach_models.dart';
import '../../utils/responsive.dart';
import 'coach_chat_shell_colors.dart';

/// 습관 개인화 제안 — 수락/거절 (거절 시 1회 재생성, 2회 거절 시 원본 유지)
class HabitPersonalizationBar extends StatelessWidget {
  const HabitPersonalizationBar({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.engine,
    required this.items,
    required this.isSubmitting,
    required this.onAccept,
    required this.onReject,
  });

  final bool isDark;
  final double horizontalPadding;
  final CoachEngine engine;
  final List<HabitPersonalizationItem> items;
  final bool isSubmitting;
  final void Function(HabitPersonalizationItem item) onAccept;
  final void Function(HabitPersonalizationItem item) onReject;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

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
                        Icons.auto_awesome_rounded,
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
                            '맞춤 생활습관 제안',
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 15),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                              color: isDark ? Colors.white : accentFg,
                            ),
                          ),
                          if (items.length > 1)
                            Text(
                              '${items.length}건 · 하나씩 확인해 주세요',
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
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        SizedBox(height: Responsive.padding(context, 12)),
                      _PersonalizationTile(
                        isDark: isDark,
                        engine: engine,
                        accent: accent,
                        accentFg: accentFg,
                        index: i,
                        total: items.length,
                        item: items[i],
                        isSubmitting: isSubmitting,
                        onAccept: onAccept,
                        onReject: onReject,
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

class _PersonalizationTile extends StatelessWidget {
  const _PersonalizationTile({
    required this.isDark,
    required this.engine,
    required this.accent,
    required this.accentFg,
    required this.index,
    required this.total,
    required this.item,
    required this.isSubmitting,
    required this.onAccept,
    required this.onReject,
  });

  final bool isDark;
  final CoachEngine engine;
  final Color accent;
  final Color accentFg;
  final int index;
  final int total;
  final HabitPersonalizationItem item;
  final bool isSubmitting;
  final void Function(HabitPersonalizationItem item) onAccept;
  final void Function(HabitPersonalizationItem item) onReject;

  @override
  Widget build(BuildContext context) {
    final innerBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : CoachChatShellColors.habitTileStrokeLight(engine);
    final bodyColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
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
                child: Row(
                  children: [
                    Container(
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
                  ],
                ),
              ),
            _CompareColumn(
              isDark: isDark,
              accent: accent,
              accentFg: accentFg,
              original: item.originalTitle,
              personalized: item.personalizedTitle,
            ),
            if (item.personalizedDetail.isNotEmpty) ...[
              SizedBox(height: Responsive.padding(context, 12)),
              Text(
                item.personalizedDetail,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: bodyColor,
                ),
              ),
            ],
            if (item.reason.isNotEmpty) ...[
              SizedBox(height: Responsive.padding(context, 10)),
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
                  item.reason,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11.5),
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: dimColor,
                  ),
                ),
              ),
            ],
            if (item.isRegenerated)
              Padding(
                padding: EdgeInsets.only(top: Responsive.padding(context, 8)),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.orange[400],
                    ),
                    SizedBox(width: Responsive.padding(context, 6)),
                    Expanded(
                      child: Text(
                        '다시 거절하면 원본으로 저장돼요.',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 11),
                          color: Colors.orange[300],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: Responsive.padding(context, 14)),
            Row(
              children: [
                Expanded(
                  child: _SecondaryCoachButton(
                    isDark: isDark,
                    accentFg: accentFg,
                    label: item.isRegenerated ? '원본으로 저장' : '다시 만들어줘',
                    onPressed:
                        isSubmitting ? null : () => onReject(item),
                  ),
                ),
                SizedBox(width: Responsive.padding(context, 10)),
                Expanded(
                  child: _PrimaryCoachButton(
                    accent: accent,
                    accentFg: accentFg,
                    label: '이대로 저장',
                    isSubmitting: isSubmitting,
                    onPressed:
                        isSubmitting ? null : () => onAccept(item),
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

class _CompareColumn extends StatelessWidget {
  const _CompareColumn({
    required this.isDark,
    required this.accent,
    required this.accentFg,
    required this.original,
    required this.personalized,
  });

  final bool isDark;
  final Color accent;
  final Color accentFg;
  final String original;
  final String personalized;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? Colors.white38 : const Color(0xFF9AA399);
    final oldStyle = TextStyle(
      fontSize: Responsive.fontSize(context, 12.5),
      height: 1.4,
      color: isDark
          ? Colors.white.withValues(alpha: 0.45)
          : const Color(0xFF8A928C),
      decoration: TextDecoration.lineThrough,
      decorationColor: muted,
    );
    final newStyle = TextStyle(
      fontSize: Responsive.fontSize(context, 14),
      height: 1.35,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.25,
      color: isDark ? Colors.white : accentFg,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기존',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 10),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: muted,
          ),
        ),
        SizedBox(height: Responsive.padding(context, 4)),
        Text(original, style: oldStyle),
        SizedBox(height: Responsive.padding(context, 12)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 8),
                vertical: Responsive.padding(context, 3),
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 12,
                    color: accent,
                  ),
                  SizedBox(width: Responsive.padding(context, 4)),
                  Text(
                    '제안',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 10),
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.padding(context, 6)),
        Text(personalized, style: newStyle),
      ],
    );
  }
}

class _PrimaryCoachButton extends StatelessWidget {
  const _PrimaryCoachButton({
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

class _SecondaryCoachButton extends StatelessWidget {
  const _SecondaryCoachButton({
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
