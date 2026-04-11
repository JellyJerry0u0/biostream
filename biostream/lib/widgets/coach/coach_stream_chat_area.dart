import 'package:flutter/material.dart';

import '../../models/coach_models.dart';
import '../common/app_chip.dart';
import 'coach_chat_shell_colors.dart';

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
    this.coachProgress,
    required this.onActionTap,
    this.footer,
  });

  final bool isDark;
  final double horizontalPadding;
  final ScrollController scrollController;
  final List<CoachChatMessage> messages;
  final Animation<double> centerScale;
  final CoachEngine engine;
  final ToolStatusEvent? currentToolStatus;
  final CoachProgressEvent? coachProgress;
  final ValueChanged<ActionItem> onActionTap;
  /// 메시지 목록 맨 아래(입력창 바로 위 느낌)에 붙는 영역 — 인사이트 로딩·차트 등
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final hasFooter = footer != null;

    if (messages.isEmpty && !hasFooter) {
      return _buildEmptyState();
    }

    final leadEmpty = messages.isEmpty;
    final itemCount =
        (leadEmpty ? 1 : messages.length) + (hasFooter ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        final isFooterSlot = hasFooter && i == itemCount - 1;
        if (isFooterSlot) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: footer!,
          );
        }
        if (leadEmpty) {
          return _buildEmptyStateForList(context);
        }
        final msg = messages[i];
        if (msg.role == 'user') {
          return _buildUserBubble(msg);
        }
        return _buildAssistantBubble(msg);
      },
    );
  }

  /// 스크롤 리스트 첫 칸용 — 전체 화면 중앙 빈 상태와 동일 콘텐츠, 최소 높이만 확보
  Widget _buildEmptyStateForList(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.42;
    return SizedBox(
      height: h.clamp(260.0, 420.0),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ScaleTransition(
            scale: centerScale,
            child: _emptyStateColumn(),
          ),
        ),
      ),
    );
  }

  Widget _emptyStateColumn() {
    final accent = CoachChatShellColors.accent(engine);
    final grad = CoachChatShellColors.emptyStateGradient(engine);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: grad),
            border: Border.all(
              color: CoachChatShellColors.emptyStateBorder(engine),
            ),
          ),
          child: Icon(
            Icons.auto_awesome,
            size: 34,
            color: accent,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AI Skin Coach',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: isDark
                ? Colors.white
                : (engine == CoachEngine.coach
                    ? const Color(0xFF1A1628)
                    : const Color(0xFF0F1E14)),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ScaleTransition(
          scale: centerScale,
          child: _emptyStateColumn(),
        ),
      ),
    );
  }

  Widget _buildUserBubble(CoachChatMessage msg) {
    final bubble = CoachChatShellColors.userBubble(engine);
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
                color: bubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: bubble.withValues(alpha: 0.15),
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
    final accent = CoachChatShellColors.accent(engine);
    final asstBg = CoachChatShellColors.assistantBubbleDark(engine);
    final ring = isDark
        ? CoachChatShellColors.avatarRingDark(engine)
        : Colors.white;
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
              color: accent.withValues(alpha: 0.15),
              border: Border.all(
                color: ring,
                width: 2,
              ),
            ),
            child: Icon(Icons.spa, size: 18, color: accent),
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
                    color: isDark ? asstBg : Colors.white,
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
                      if (msg.isStreaming &&
                          currentToolStatus == null &&
                          coachProgress != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                            ),
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
                                  coachProgress!.displayText,
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
                      if (msg.isStreaming &&
                          currentToolStatus == null &&
                          coachProgress == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (engine == CoachEngine.coach &&
                    msg.actions.isNotEmpty &&
                    !msg.isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: msg.actions
                          .map((a) => AppAccentChip(
                                label: a.label,
                                accentColor: accent,
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
