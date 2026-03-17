import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../common/app_chip.dart';

class CoachChecklistItem extends StatelessWidget {
  const CoachChecklistItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isChecked,
    required this.onTap,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final bool isChecked;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(Responsive.padding(context, 12)),
          decoration: BoxDecoration(
            color: isChecked
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[50])
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: Responsive.fontSize(context, 24),
                height: Responsive.fontSize(context, 24),
                decoration: BoxDecoration(
                  color:
                      isChecked ? const Color(0xFF37EC13) : Colors.transparent,
                  border: Border.all(
                    color: isChecked
                        ? const Color(0xFF37EC13)
                        : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isChecked
                    ? Icon(
                        Icons.check,
                        size: Responsive.iconSize(context, 16),
                        color: Colors.black,
                      )
                    : null,
              ),
              SizedBox(width: Responsive.padding(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 14),
                        fontWeight:
                            isChecked ? FontWeight.normal : FontWeight.w500,
                        color: isChecked
                            ? (isDark ? Colors.grey[400] : Colors.grey[400])
                            : (isDark ? Colors.white : Colors.black87),
                        decoration:
                            isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    SizedBox(height: Responsive.padding(context, 2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
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

class CoachTypingDot extends StatefulWidget {
  const CoachTypingDot({super.key, required this.delay});

  final int delay;

  @override
  State<CoachTypingDot> createState() => _CoachTypingDotState();
}

class _CoachTypingDotState extends State<CoachTypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value * 3 + (widget.delay / 1000)) % 1.0;
        final scale = value < 0.4
            ? (value / 0.4)
            : value > 0.8
                ? (1 - value) / 0.2
                : 1.0;

        return Transform.scale(
          scale: scale.clamp(0.0, 1.0),
          child: Container(
            width: Responsive.fontSize(context, 8),
            height: Responsive.fontSize(context, 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class CoachQuickActionChip extends StatelessWidget {
  const CoachQuickActionChip({
    super.key,
    required this.text,
    required this.isDark,
  });

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceChip(
      text: text,
      isDark: isDark,
      onTap: () {
        debugPrint('Quick action: $text');
      },
      borderRadius: 9999,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 24),
        vertical: Responsive.padding(context, 14),
      ),
      fontSize: Responsive.fontSize(context, 12),
      fontWeight: FontWeight.w600,
    );
  }
}
