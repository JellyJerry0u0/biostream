import 'package:flutter/material.dart';

import '../../models/coach_models.dart';
import '../common/app_chip.dart';

class CoachStreamChatArea extends StatelessWidget {
  const CoachStreamChatArea({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.scrollController,
    required this.messages,
    required this.centerScale,
    required this.engine,
    required this.currentToolStatus,
    required this.onActionTap,
  });

  final bool isDark;
  final double horizontalPadding;
  final ScrollController scrollController;
  final List<CoachChatMessage> messages;
  final Animation<double> centerScale;
  final CoachEngine engine;
  final ToolStatusEvent? currentToolStatus;
  final ValueChanged<ActionItem> onActionTap;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: scrollController,
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        if (msg.role == 'user') {
          return _buildUserBubble(msg);
        }
        return _buildAssistantBubble(msg);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ScaleTransition(
          scale: centerScale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF37EC13).withValues(alpha: 0.28),
                      const Color(0xFF37EC13).withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF37EC13).withValues(alpha: 0.26),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 34,
                  color: Color(0xFF37EC13),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'AI Skin Coach',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: isDark ? Colors.white : const Color(0xFF0F1E14),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '리포트 기반 맞춤 코칭과\n생활습관 개선 팁을 제공합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserBubble(CoachChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF37EC13),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF37EC13).withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                msg.content,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(CoachChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF37EC13).withValues(alpha: 0.15),
              border: Border.all(
                color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                width: 2,
              ),
            ),
            child: const Icon(Icons.spa, size: 18, color: Color(0xFF37EC13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skin Coach',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[100]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.content.isEmpty && msg.isStreaming
                            ? '...'
                            : msg.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (msg.isStreaming && currentToolStatus != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF7C4DFF)
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Color(0xFF7C4DFF),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  currentToolStatus!.displayText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF7C4DFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (msg.isStreaming && currentToolStatus == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: (engine == CoachEngine.deep
                                      ? const Color(0xFF7C4DFF)
                                      : const Color(0xFF37EC13))
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (msg.actions.isNotEmpty && !msg.isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: msg.actions
                          .map((a) => AppAccentChip(
                                label: a.label,
                                onTap: () => onActionTap(a),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
