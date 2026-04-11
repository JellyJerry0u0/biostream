import 'package:flutter/material.dart';

import '../../screens/home/home_models.dart';

/// 홈 — 생활습관 행 탭 시 상세·삭제 (완료는 목록에서 원형 버튼으로 토글)
Future<void> showHomeQuestDetailDialog({
  required BuildContext context,
  required HomeQuestItem item,
  required Color accentColor,
  required Future<void> Function(HomeQuestItem item, BuildContext dialogContext)
      onConfirmRemoveCommitted,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (dialogContext, _, __) {
      return _HomeQuestDetailModal(
        key: ValueKey<String>('home_quest_detail_${item.id}'),
        item: item,
        accentColor: accentColor,
        onConfirmRemoveCommitted: onConfirmRemoveCommitted,
        dialogContext: dialogContext,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<bool?> showHomeQuestRemoveConfirmDialog({
  required BuildContext context,
  required String habitTitle,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, _) {
      return Center(
        child: _RemoveConfirmCard(
          habitTitle: habitTitle,
          onCancel: () => Navigator.of(ctx).pop(false),
          onDelete: () => Navigator.of(ctx).pop(true),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _HomeQuestDetailModal extends StatefulWidget {
  const _HomeQuestDetailModal({
    super.key,
    required this.item,
    required this.accentColor,
    required this.onConfirmRemoveCommitted,
    required this.dialogContext,
  });

  final HomeQuestItem item;
  final Color accentColor;
  final Future<void> Function(HomeQuestItem item, BuildContext dialogContext)
      onConfirmRemoveCommitted;
  final BuildContext dialogContext;

  @override
  State<_HomeQuestDetailModal> createState() => _HomeQuestDetailModalState();
}

class _HomeQuestDetailModalState extends State<_HomeQuestDetailModal> {
  bool _removeConfirmMode = false;
  bool _removeBusy = false;

  static const _fg = Color(0xFF102217);
  static const _muted = Color(0xFF5C6560);

  void _popDialog() {
    Navigator.of(widget.dialogContext).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final item = widget.item;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          color: const Color(0xFFFAFCFA),
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_removeConfirmMode)
                _buildConfirmHeader(accent)
              else
                _buildDetailHeader(accent, item),
              if (_removeConfirmMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: _RemoveConfirmStepBody(
                    habitTitle: item.title,
                    deleteBusy: _removeBusy,
                    onCancel: () => setState(() => _removeConfirmMode = false),
                    onDelete: _removeBusy
                        ? null
                        : () async {
                            setState(() => _removeBusy = true);
                            try {
                              await widget.onConfirmRemoveCommitted(
                                item,
                                widget.dialogContext,
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _removeBusy = false);
                              }
                            }
                          },
                  ),
                )
              else ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4F1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE0E8E3),
                            ),
                          ),
                          child: SelectableText(
                            item.detail.trim().isNotEmpty
                                ? item.detail
                                : '상세 설명이 없어요.',
                            style: const TextStyle(
                              color: Color(0xFF2A3830),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                  child: item.committedActionId != null
                      ? TextButton.icon(
                          onPressed: () =>
                              setState(() => _removeConfirmMode = true),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Colors.red[700],
                          ),
                          label: Text(
                            '저장 목록에서 삭제',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.red[700],
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            foregroundColor: Colors.red[700],
                            backgroundColor: const Color(0xFFFFF5F5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          '리포트에서만 보이는 추천 행동이에요. 서버에 저장하면 여기서 관리할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailHeader(Color accent, HomeQuestItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.04),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: accent.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.spa_rounded,
              color: accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '생활습관',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.35,
                    color: _fg,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _popDialog,
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF7A8A82),
            ),
            icon: const Icon(Icons.close_rounded, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmHeader(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.04),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: accent.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _removeBusy
                ? null
                : () => setState(() => _removeConfirmMode = false),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF5C6560),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            tooltip: '뒤로',
          ),
          Expanded(
            child: Text(
              '저장 목록에서 제거',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: _fg,
              ),
            ),
          ),
          IconButton(
            onPressed: _removeBusy ? null : _popDialog,
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF7A8A82),
            ),
            icon: const Icon(Icons.close_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}

/// 삭제 확인 본문 (같은 다이얼로그 안 전환용 + 단독 카드에서 공통 사용)
class _RemoveConfirmStepBody extends StatelessWidget {
  const _RemoveConfirmStepBody({
    required this.habitTitle,
    required this.onCancel,
    required this.onDelete,
    this.deleteBusy = false,
  });

  final String habitTitle;
  final VoidCallback onCancel;
  final Future<void> Function()? onDelete;
  final bool deleteBusy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.folder_off_outlined,
          size: 40,
          color: Colors.red[400],
        ),
        const SizedBox(height: 16),
        const Text(
          '저장 목록에서 제거할까요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF102217),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '「$habitTitle」',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C6560),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: deleteBusy ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5C6560),
                  side: const BorderSide(color: Color(0xFFD5DCD5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '취소',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: deleteBusy ? null : onDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: deleteBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '삭제',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RemoveConfirmCard extends StatelessWidget {
  const _RemoveConfirmCard({
    required this.habitTitle,
    required this.onCancel,
    required this.onDelete,
  });

  final String habitTitle;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.86,
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFCFA),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
          border: Border.all(color: const Color(0xFFE8EDE8)),
        ),
        child: _RemoveConfirmStepBody(
          habitTitle: habitTitle,
          onCancel: onCancel,
          onDelete: () async => onDelete(),
        ),
      ),
    );
  }
}
