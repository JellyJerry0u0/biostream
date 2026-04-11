import 'package:flutter/material.dart';

import '../utils/responsive.dart';

class ReportTabsBar extends StatelessWidget {
  final List<String> tabs;
  final String selectedTab;
  final Function(String) onTabSelected;

  const ReportTabsBar({
    super.key,
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
  });

  static const Color _primary = Color(0xFF37EC13);
  static const Color _textOnLight = Color(0xFF101B0D);

  static const Map<String, String> _tabLabels = {
    'summary': '요약',
    'goals': '목표',
    'sleep': '수면',
    'uv': '자외선',
    'smoking': '흡연',
    'drinking': '음주',
    'stress': '스트레스',
    'lifestyle': '생활습관',
    'activity': '활동',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade200;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: Responsive.fontSize(context, 48),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 8),
            ),
            itemCount: tabs.length,
            separatorBuilder: (_, __) =>
                SizedBox(width: Responsive.padding(context, 2)),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              final isSelected = tab == selectedTab;
              final label = _tabLabels[tab] ?? tab;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTabSelected(tab),
                  borderRadius: BorderRadius.circular(8),
                  splashColor: _primary.withValues(alpha: 0.1),
                  highlightColor: _primary.withValues(alpha: 0.05),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 14),
                      vertical: Responsive.padding(context, 10),
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? _primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 13.5),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: -0.15,
                        height: 1.25,
                        color: isSelected
                            ? (isDark ? Colors.white : _textOnLight)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.45)
                                : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 1, thickness: 1, color: dividerColor),
      ],
    );
  }
}
