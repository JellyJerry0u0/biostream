import 'package:flutter/material.dart';

import '../../screens/home_screen.dart';
import '../../utils/responsive.dart';

class SurveyProgressHeader extends StatelessWidget {
  const SurveyProgressHeader({
    super.key,
    required this.isDark,
    required this.currentPage,
    required this.totalPages,
    required this.showHomeButtonOnFirstPage,
    required this.onJumpToSummary,
  });

  final bool isDark;
  final int currentPage;
  final int totalPages;
  final bool showHomeButtonOnFirstPage;
  final VoidCallback onJumpToSummary;

  @override
  Widget build(BuildContext context) {
    final isSummaryPage = currentPage == totalPages - 1;
    return AnimatedOpacity(
      opacity: isSummaryPage ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: isSummaryPage ? 0 : null,
        child: Container(
          padding: EdgeInsets.all(Responsive.padding(context, 16)),
          child: Column(
            children: [
              if (showHomeButtonOnFirstPage && currentPage == 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.home,
                      size: Responsive.iconSize(context, 16),
                      color: const Color(0xFF37EC13),
                    ),
                    label: Text(
                      '홈으로 돌아가기',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        color: const Color(0xFF37EC13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${currentPage + 1} / $totalPages',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF37EC13),
                    ),
                  ),
                  if (currentPage < totalPages - 1)
                    TextButton(
                      onPressed: onJumpToSummary,
                      child: Text(
                        '요약으로',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12),
                          color: const Color(0xFF37EC13),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: Responsive.padding(context, 8)),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: (currentPage + 1) / totalPages,
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFD3E7CF),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF37EC13)),
                    minHeight: Responsive.fontSize(context, 4),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
