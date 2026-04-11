import 'package:flutter/material.dart';

import '../../screens/today_me/today_me_models.dart';
import 'today_me_habit_section.dart';
import 'today_me_lifestyle_charts_section.dart';
import 'today_me_lifestyle_intro_layer.dart';
import 'today_me_week_snapshot_strip.dart';

String _headerDateLabel() {
  final n = DateTime.now();
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${n.year}년 ${n.month}월 ${n.day}일 (${weekdays[n.weekday - 1]})';
}

/// 대시보드(주간 차트)가 나타날 때만 짧게 페이드·슬라이드 인
class _LifestyleDashboardEntrance extends StatefulWidget {
  const _LifestyleDashboardEntrance({
    required this.visible,
    required this.history,
    required this.primaryColor,
  });

  final bool visible;
  final List<LifestyleHistoryDay> history;
  final Color primaryColor;

  @override
  State<_LifestyleDashboardEntrance> createState() =>
      _LifestyleDashboardEntranceState();
}

class _LifestyleDashboardEntranceState extends State<_LifestyleDashboardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final CurvedAnimation _curve;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _curve = CurvedAnimation(
      parent: _ac,
      curve: Curves.easeOutCubic,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_curve);
    if (widget.visible) {
      _ac.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _LifestyleDashboardEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _ac.forward(from: 0);
    } else if (!widget.visible && oldWidget.visible) {
      _ac.reset();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const SizedBox.shrink();
    }
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: _slide,
        child: TodayMeLifestyleChartsSection(
          history: widget.history,
          primaryColor: widget.primaryColor,
        ),
      ),
    );
  }
}

class TodayMeContent extends StatelessWidget {
  const TodayMeContent({
    super.key,
    required this.primaryColor,
    required this.todayLifestyleItems,
    required this.lifestyleHistory,
    required this.lifestyleNotice,
    required this.showLifestyleIntroBlur,
    required this.onLifestyleIntroTap,
    required this.showDashboardCharts,
    required this.lifestyleSectionExpanded,
    required this.onLifestyleSectionExpandedChanged,
    required this.onLifestyleItemTap,
    this.onSaveLifestyleBatch,
    required this.headerSlide,
    required this.headerOpacity,
    required this.carouselSlide,
    required this.carouselOpacity,
    required this.metricsSlide,
    required this.metricsOpacity,
    required this.bottomPadding,
    required this.savedSnapshotDateKeys,
    required this.onWeekEmptyDayTap,
  });

  final Color primaryColor;
  final List<TodayLifestyleItem> todayLifestyleItems;
  final List<LifestyleHistoryDay> lifestyleHistory;
  final String? lifestyleNotice;
  final bool showLifestyleIntroBlur;
  final VoidCallback onLifestyleIntroTap;
  final bool showDashboardCharts;
  final bool lifestyleSectionExpanded;
  final ValueChanged<bool> onLifestyleSectionExpandedChanged;
  final void Function(TodayLifestyleItem item) onLifestyleItemTap;
  final VoidCallback? onSaveLifestyleBatch;
  final Animation<Offset> headerSlide;
  final Animation<double> headerOpacity;
  final Animation<Offset> carouselSlide;
  final Animation<double> carouselOpacity;
  final Animation<Offset> metricsSlide;
  final Animation<double> metricsOpacity;
  final double bottomPadding;
  final Set<String> savedSnapshotDateKeys;
  final ValueChanged<DateTime> onWeekEmptyDayTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SlideTransition(
            position: headerSlide,
            child: FadeTransition(
              opacity: headerOpacity,
              child: _buildHeader(),
            ),
          ),
          const SizedBox(height: 4),
          SlideTransition(
            position: carouselSlide,
            child: FadeTransition(
              opacity: carouselOpacity,
              child: TodayMeWeekSnapshotStrip(
                primaryColor: primaryColor,
                savedSnapshotDateKeys: savedSnapshotDateKeys,
                onEmptyDayTap: onWeekEmptyDayTap,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SlideTransition(
            position: metricsSlide,
            child: FadeTransition(
              opacity: metricsOpacity,
              child: Column(
                children: [
                  _LifestyleDashboardEntrance(
                    visible: showDashboardCharts,
                    history: lifestyleHistory,
                    primaryColor: primaryColor,
                  ),
                  _buildMetricsPanel(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TodayMeHabitSection(primaryColor: primaryColor),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headerDateLabel(),
            style: const TextStyle(
              color: Color(0xFF7A8380),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '나의 기록',
            style: TextStyle(
              color: Color(0xFF102217),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsPanel() {
    final expandedForContent =
        showLifestyleIntroBlur || lifestyleSectionExpanded;

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: showLifestyleIntroBlur
                ? null
                : () => onLifestyleSectionExpandedChanged(
                      !lifestyleSectionExpanded,
                    ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '오늘의 나의 생활',
                          style: TextStyle(
                            color: Color(0xFF102217),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showLifestyleIntroBlur
                              ? '안내 카드를 누르면 기록을 시작할 수 있어요'
                              : lifestyleSectionExpanded
                                  ? '항목을 탭해 수정한 뒤, 하단에서 한 번에 저장해 주세요'
                                  : '탭하면 다시 펼쳐요',
                          style: const TextStyle(
                            color: Color(0xFF92A29B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        color: Color(0xFF16984B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!showLifestyleIntroBlur) ...[
                    const SizedBox(width: 6),
                    Icon(
                      lifestyleSectionExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFF92A29B),
                      size: 28,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (expandedForContent) ...[
          const SizedBox(height: 14),
          if (lifestyleNotice != null && lifestyleNotice!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6FAF7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE3ECE7)),
              ),
              child: Text(
                lifestyleNotice!,
                style: const TextStyle(
                  color: Color(0xFF6B7E75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todayLifestyleItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.48,
            ),
            itemBuilder: (context, index) {
              final item = todayLifestyleItems[index];
              return _TodayLifestyleCard(
                item: item,
                primaryColor: primaryColor,
                onTap: item.editable ? () => onLifestyleItemTap(item) : null,
              );
            },
          ),
          if (onSaveLifestyleBatch != null &&
              !showLifestyleIntroBlur &&
              lifestyleSectionExpanded) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSaveLifestyleBatch,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: const Color(0xFF102217),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '오늘의 생활습관 저장',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ],
    );

    final layered = TodayMeLifestyleIntroLayer(
      showIntroGate: showLifestyleIntroBlur,
      onIntroDismissed: onLifestyleIntroTap,
      primaryColor: primaryColor,
      child: inner,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF102217).withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE8F0EB)),
            ),
            padding: const EdgeInsets.all(16),
            child: layered,
          ),
        ),
      ),
    );
  }
}

class _TodayLifestyleCard extends StatelessWidget {
  const _TodayLifestyleCard({
    required this.item,
    required this.primaryColor,
    this.onTap,
  });

  final TodayLifestyleItem item;
  final Color primaryColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8F0EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, color: primaryColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      color: Color(0xFF7A8380),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.edit, size: 14, color: Colors.grey[400]),
              ],
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.value,
                        style: const TextStyle(
                          color: Color(0xFF102217),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.unit.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            item.unit,
                            style: const TextStyle(
                              color: Color(0xFF96A09B),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
