import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class ResultScreenHeader extends StatelessWidget {
  final bool isDark;
  final double horizontalPadding;
  final bool showNotionButton;
  final VoidCallback onBack;
  final VoidCallback onHome;
  final VoidCallback onShare;
  final VoidCallback onOpenNotion;

  const ResultScreenHeader({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.showNotionButton,
    required this.onBack,
    required this.onHome,
    required this.onShare,
    required this.onOpenNotion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
            .withValues(alpha: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _roundIconButton(
            context: context,
            icon: Icons.arrow_back,
            onTap: onBack,
          ),
          Text(
            'Results',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : const Color(0xFF101B0D),
            ),
          ),
          _roundIconButton(
            context: context,
            icon: Icons.home_outlined,
            iconSize: 22,
            onTap: onHome,
          ),
          if (showNotionButton) ...[
            SizedBox(width: Responsive.padding(context, 8)),
            _roundIconButton(
              context: context,
              icon: Icons.description_outlined,
              onTap: onOpenNotion,
            ),
          ],
          _roundIconButton(
            context: context,
            icon: Icons.share,
            onTap: onShare,
          ),
        ],
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
