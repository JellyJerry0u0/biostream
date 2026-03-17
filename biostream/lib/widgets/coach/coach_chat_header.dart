import 'package:flutter/material.dart';

import '../../models/coach_models.dart';
import '../../utils/responsive.dart';
import '../common/app_icon_button.dart';

class CoachChatHeader extends StatelessWidget {
  const CoachChatHeader({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.isConnected,
    required this.engine,
    required this.isAssistantStreaming,
    required this.onBack,
    required this.onToggleEngine,
  });

  final bool isDark;
  final double horizontalPadding;
  final bool isConnected;
  final CoachEngine engine;
  final bool isAssistantStreaming;
  final VoidCallback onBack;
  final VoidCallback onToggleEngine;

  @override
  Widget build(BuildContext context) {
    final isDeep = engine == CoachEngine.deep;
    final accentColor =
        isDeep ? const Color(0xFF7C4DFF) : const Color(0xFF37EC13);

    return Container(
      padding: EdgeInsets.only(
        top: Responsive.padding(context, 12),
        bottom: Responsive.padding(context, 12),
        left: horizontalPadding,
        right: horizontalPadding,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
            .withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back,
            onTap: onBack,
            iconColor: isDark ? Colors.white : Colors.black87,
            iconSize: 22,
            buttonSize: 38,
            borderRadius: 20,
          ),
          const SizedBox(width: 6),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'AI Skin Coach',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 17),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isConnected ? accentColor : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isConnected ? 'Online' : 'Connecting...',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 10),
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isAssistantStreaming ? null : onToggleEngine,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDeep ? Icons.psychology : Icons.bolt,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isDeep ? 'Deep' : 'Quick',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
