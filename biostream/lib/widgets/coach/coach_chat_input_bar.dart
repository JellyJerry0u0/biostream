import 'package:flutter/material.dart';

import '../../models/coach_models.dart';
import '../../utils/responsive.dart';
import '../common/app_chip.dart';
import '../common/app_message_input_field.dart';
import 'coach_chat_shell_colors.dart';

class CoachChatInputBar extends StatelessWidget {
  const CoachChatInputBar({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.engine,
    required this.inputController,
    required this.isAssistantStreaming,
    required this.onSend,
    required this.onQuickAction,
  });

  final bool isDark;
  final double horizontalPadding;
  final CoachEngine engine;
  final TextEditingController inputController;
  final bool isAssistantStreaming;
  final VoidCallback onSend;
  final ValueChanged<String> onQuickAction;

  @override
  Widget build(BuildContext context) {
    final accent = CoachChatShellColors.accent(engine);
    final chipDark = CoachChatShellColors.quickChipDark(engine);
    final inputShell = CoachChatShellColors.inputFieldShellDark(engine);

    return Container(
      decoration: BoxDecoration(
        color: CoachChatShellColors.stripBg(isDark: isDark, engine: engine),
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
          if (engine == CoachEngine.quick) ...[
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding, vertical: 10),
                  children: [
                    AppSurfaceChip(
                      text: '오늘의 플랜',
                      isDark: isDark,
                      darkSurfaceColor: chipDark,
                      onTap: () => onQuickAction(
                          '오늘 내가 실천하면 좋을 피부 관리법을 간단히 알려줘'),
                    ),
                    const SizedBox(width: 8),
                    AppSurfaceChip(
                      text: '리포트 해설',
                      isDark: isDark,
                      darkSurfaceColor: chipDark,
                      onTap: () =>
                          onQuickAction('내 리포트의 핵심 결과를 간단히 요약해줘'),
                    ),
                    const SizedBox(width: 8),
                    AppSurfaceChip(
                      text: '수면 관리 팁',
                      isDark: isDark,
                      darkSurfaceColor: chipDark,
                      onTap: () => onQuickAction(
                          '수면이 피부에 미치는 영향과 관리법을 알려줘'),
                    ),
                    const SizedBox(width: 8),
                    AppSurfaceChip(
                      text: '자외선 대응',
                      isDark: isDark,
                      darkSurfaceColor: chipDark,
                      onTap: () => onQuickAction('자외선 차단 관리법을 알려줘'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              bottom: Responsive.padding(context, 20),
              top: engine == CoachEngine.quick ? 2 : 10,
            ),
            child: AppMessageInputField(
              isDark: isDark,
              controller: inputController,
              hintText: '피부 건강에 대해 물어보세요...',
              onSend: onSend,
              isSendDisabled: isAssistantStreaming,
              activeSendColor: accent,
              darkShellColor: inputShell,
              leading: const SizedBox(width: 12),
            ),
          ),
        ],
      ),
    );
  }
}
