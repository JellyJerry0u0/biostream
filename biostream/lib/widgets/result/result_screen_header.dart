import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class ResultScreenHeader extends StatelessWidget {
  final bool isDark;
  final double horizontalPadding;
  final bool showNotionButton;
  final VoidCallback onBack;
  final VoidCallback onOpenNotion;

  const ResultScreenHeader({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.showNotionButton,
    required this.onBack,
    required this.onOpenNotion,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: Responsive.fontSize(context, 16),
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
      color: isDark
          ? Colors.white.withValues(alpha: 0.9)
          : const Color(0xFF101B0D),
    );
    final barHeight = Responsive.fontSize(context, 40);
    final sideSlot = Responsive.fontSize(context, 40);
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
            .withValues(alpha: 0.8),
      ),
      child: SizedBox(
        height: barHeight,
        child: Row(
          children: [
            SizedBox(
              width: sideSlot,
              height: barHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _roundIconButton(
                  context: context,
                  icon: Icons.arrow_back,
                  onTap: onBack,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Weekly Report',
                style: titleStyle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: sideSlot,
              height: barHeight,
              child: showNotionButton
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: _roundIconButton(
                        context: context,
                        icon: Icons.description_outlined,
                        onTap: onOpenNotion,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 24,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          width: Responsive.fontSize(context, 40),
          height: Responsive.fontSize(context, 40),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: Responsive.iconSize(context, iconSize),
            color: isDark ? Colors.white : const Color(0xFF101B0D),
          ),
        ),
      ),
    );
  }
}
