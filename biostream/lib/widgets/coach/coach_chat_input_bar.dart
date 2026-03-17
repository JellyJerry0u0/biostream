import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../common/app_chip.dart';
import '../common/app_message_input_field.dart';

class CoachChatInputBar extends StatelessWidget {
  const CoachChatInputBar({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.inputController,
    required this.isAssistantStreaming,
    required this.onSend,
    required this.onQuickAction,
  });

  final bool isDark;
  final double horizontalPadding;
  final TextEditingController inputController;
  final bool isAssistantStreaming;
  final VoidCallback onSend;
  final ValueChanged<String> onQuickAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6))
            .withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey[200]!,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 10),
              children: [
                AppSurfaceChip(
                  text: '오늘의 플랜',
                  isDark: isDark,
                  onTap: () => onQuickAction('오늘 내가 실천하면 좋을 피부 관리법을 간단히 알려줘'),
                ),
                const SizedBox(width: 8),
                AppSurfaceChip(
                  text: '리포트 해설',
                  isDark: isDark,
                  onTap: () => onQuickAction('내 리포트의 핵심 결과를 간단히 요약해줘'),
                ),
                const SizedBox(width: 8),
                AppSurfaceChip(
                  text: '수면 관리 팁',
                  isDark: isDark,
                  onTap: () => onQuickAction('수면이 피부에 미치는 영향과 관리법을 알려줘'),
                ),
                const SizedBox(width: 8),
                AppSurfaceChip(
                  text: '자외선 대응',
                  isDark: isDark,
                  onTap: () => onQuickAction('자외선 차단 관리법을 알려줘'),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: Responsive.padding(context, 20),
              top: 2,
            ),
            child: AppMessageInputField(
              isDark: isDark,
              controller: inputController,
              hintText: '피부 건강에 대해 물어보세요...',
              onSend: onSend,
              isSendDisabled: isAssistantStreaming,
              leading: const SizedBox(width: 12),
            ),
          ),
        ],
      ),
    );
  }
}
