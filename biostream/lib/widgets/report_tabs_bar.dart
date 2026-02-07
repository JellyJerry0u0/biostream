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

  static const Map<String, String> _tabLabels = {
    'goals': '목표',
    'sleep': '수면',
    'uv': '자외선',
    'lifestyle': '생활습관',
    'activity': '활동',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: Responsive.fontSize(context, 56),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.padding(context, 16),
        ),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = tab == selectedTab;
          final label = _tabLabels[tab] ?? tab;

          return Padding(
            padding: EdgeInsets.only(
              right: Responsive.padding(context, 12),
            ),
            child: GestureDetector(
              onTap: () => onTabSelected(tab),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.padding(context, 20),
                  vertical: Responsive.padding(context, 12),
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF37EC13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF101B0D)
                          : (isDark ? Colors.white70 : Colors.grey[700]),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
