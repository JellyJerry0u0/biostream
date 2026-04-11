import 'package:flutter/material.dart';

import '../../screens/home/home_models.dart';

class HomeQuestSection extends StatelessWidget {
  const HomeQuestSection({
    super.key,
    required this.primaryColor,
    required this.gameCardColor,
    required this.isLoadingQuests,
    required this.questError,
    required this.questItems,
    required this.onOpenQuestEditor,
    required this.onToggleDoneOnList,
    required this.onGoToReport,
  });

  final Color primaryColor;
  final Color gameCardColor;
  final bool isLoadingQuests;
  final String? questError;
  final List<HomeQuestItem> questItems;
  /// 항목(행) 탭 시 편집·삭제 다이얼로그
  final ValueChanged<HomeQuestItem> onOpenQuestEditor;
  /// 오른쪽 완료 원 탭 시 오늘 완료 토글
  final Future<void> Function(HomeQuestItem item, bool done) onToggleDoneOnList;
  final VoidCallback onGoToReport;

  @override
  Widget build(BuildContext context) {
    final int totalCount = questItems.length;
    final int doneCount = questItems.where((item) => item.isDone).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: gameCardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '저장한 생활습관',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '계정에 저장된 모든 항목',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  '$doneCount/$totalCount 완료',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '오른쪽 원: 오늘 완료 · 행(제목) 탭: 상세·삭제',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (isLoadingQuests)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
            )
          else if (questError != null)
            _questFallback()
          else
            ...questItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QuestListRow(
                  item: item,
                  primaryColor: primaryColor,
                  onOpenDetail: () => onOpenQuestEditor(item),
                  onToggleDone: onToggleDoneOnList,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _questFallback() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questError ?? '맞춤 솔루션을 불러오지 못했습니다.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onGoToReport,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '리포트 만들러 가기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestListRow extends StatefulWidget {
  const _QuestListRow({
    required this.item,
    required this.primaryColor,
    required this.onOpenDetail,
    required this.onToggleDone,
  });

  final HomeQuestItem item;
  final Color primaryColor;
  final VoidCallback onOpenDetail;
  final Future<void> Function(HomeQuestItem item, bool done) onToggleDone;

  @override
  State<_QuestListRow> createState() => _QuestListRowState();
}

class _QuestListRowState extends State<_QuestListRow>
    with SingleTickerProviderStateMixin {
  bool _toggleBusy = false;

  /// `HomeQuestItem.isDone`이 같은 객체에서 변이되면 `oldWidget.item.isDone` 비교로는 전환을 못 잡음.
  bool? _lastSyncedIsDone;

  /// 핫 리로드 시 `State`가 유지되면 `initState`가 다시 안 돌아가 `late`가 터질 수 있어 지연 초기화.
  AnimationController? _highlightCtrl;
  CurvedAnimation? _highlightCurve;

  /// 형광펜 느낌 (진한 네온 라임 + 아주 약한 브랜드 틴트)
  static Color _fluoro(Color brand) {
    const neon = Color(0xFFB8FF1A);
    return Color.lerp(neon, brand, 0.1)!;
  }

  void _ensureHighlightAnimations() {
    if (_highlightCtrl != null) return;
    final c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    final curve = CurvedAnimation(
      parent: c,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _highlightCtrl = c;
    _highlightCurve = curve;
    if (widget.item.isDone) {
      c.value = 1.0;
    }
  }

  Animation<double> get _highlight {
    _ensureHighlightAnimations();
    return _highlightCurve!;
  }

  @override
  void didUpdateWidget(covariant _QuestListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureHighlightAnimations();
    final c = _highlightCtrl!;
    final now = widget.item.isDone;
    final prev = _lastSyncedIsDone;
    if (prev != null && prev != now) {
      if (now) {
        c.forward(from: 0);
      } else {
        c.reverse();
      }
    }
  }

  @override
  void dispose() {
    _highlightCurve?.dispose();
    _highlightCtrl?.dispose();
    super.dispose();
  }

  Future<void> _onBadgeTap() async {
    if (_toggleBusy) return;
    setState(() => _toggleBusy = true);
    await widget.onToggleDone(widget.item, !widget.item.isDone);
    if (mounted) setState(() => _toggleBusy = false);
  }

  static const Duration _animDuration = Duration(milliseconds: 360);
  static const Curve _animCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final isDone = widget.item.isDone;
    final primaryColor = widget.primaryColor;

    final row = AnimatedContainer(
      duration: _animDuration,
      curve: _animCurve,
      decoration: BoxDecoration(
        color: isDone ? Colors.white : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone
              ? primaryColor.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.07),
          width: isDone ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDone
                ? primaryColor.withValues(alpha: 0.34)
                : Colors.transparent,
            blurRadius: isDone ? 22 : 0,
            offset: Offset(0, isDone ? 7 : 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onOpenDetail,
                  splashFactory: NoSplash.splashFactory,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final measureStyle = TextStyle(
                          color: isDone
                              ? const Color(0xFF102217)
                              : Colors.white.withValues(alpha: 0.94),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                          letterSpacing: -0.2,
                        );
                        final tp = TextPainter(
                          text: TextSpan(
                            text: widget.item.title,
                            style: measureStyle,
                          ),
                          maxLines: 2,
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                          ellipsis: '…',
                        )..layout(maxWidth: constraints.maxWidth);
                        final textW = tp.width;
                        final textH = tp.height.clamp(1.0, 120.0);

                        return AnimatedBuilder(
                          animation: _highlight,
                          builder: (context, child) {
                            final t = _highlight.value.clamp(0.0, 1.0);
                            final ink = _fluoro(primaryColor);
                            final w = textW * t;
                            return Stack(
                              clipBehavior: Clip.hardEdge,
                              alignment: Alignment.topLeft,
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  width: w,
                                  height: textH,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          ink.withValues(alpha: 0.92 * t),
                                          ink.withValues(alpha: 0.78 * t),
                                        ],
                                      ),
                                      boxShadow: t > 0.05
                                          ? [
                                              BoxShadow(
                                                color: primaryColor
                                                    .withValues(alpha: 0.35 * t),
                                                blurRadius: 8 * t,
                                                offset: Offset(1.5 * t, 0),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                                child!,
                              ],
                            );
                          },
                          child: AnimatedDefaultTextStyle(
                            duration: _animDuration,
                            curve: _animCurve,
                            style: measureStyle,
                            child: Text(
                              widget.item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleBusy ? null : _onBadgeTap,
                customBorder: const CircleBorder(),
                splashFactory: NoSplash.splashFactory,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: SizedBox(
                  width: 52,
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: isDone ? '오늘 완료 취소' : '오늘 완료로 표시',
                      child: _toggleBusy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              ),
                            )
                          : _DoneBadge(
                              isDone: isDone,
                              primaryColor: primaryColor,
                              lightRow: isDone,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // 같은 `item` 참조에서 `isDone`만 변이되는 경우 `oldWidget.item.isDone` 비교가 무의미해져,
    // 직전 build에서 저장한 값과 `didUpdateWidget`에서 비교한다.
    _lastSyncedIsDone = widget.item.isDone;
    return row;
  }
}

class _DoneBadge extends StatelessWidget {
  const _DoneBadge({
    required this.isDone,
    required this.primaryColor,
    required this.lightRow,
  });

  final bool isDone;
  final Color primaryColor;
  /// 완료 상태일 때 행 배경이 밝음 — 미완료 링 색 대비용
  final bool lightRow;

  static const Duration _d = Duration(milliseconds: 360);
  static const Curve _c = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _d,
      curve: _c,
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? primaryColor.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: lightRow ? 0.12 : 0.05),
        border: Border.all(
          color: isDone
              ? primaryColor.withValues(alpha: 0.75)
              : (lightRow
                  ? const Color(0xFF102217).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.12)),
          width: isDone ? 2 : 1,
        ),
        boxShadow: isDone
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: AnimatedSwitcher(
        duration: _d,
        switchInCurve: _c,
        switchOutCurve: Curves.easeInCubic,
        child: isDone
            ? Icon(
                Icons.check_rounded,
                key: const ValueKey('done'),
                size: 19,
                color: primaryColor,
              )
            : Icon(
                Icons.circle_outlined,
                key: const ValueKey('open'),
                size: 17,
                color: lightRow
                    ? const Color(0xFF102217).withValues(alpha: 0.28)
                    : Colors.white.withValues(alpha: 0.22),
              ),
      ),
    );
  }
}
