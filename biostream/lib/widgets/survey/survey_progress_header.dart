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
  });

  final bool isDark;
  final int currentPage;
  final int totalPages;
  final bool showHomeButtonOnFirstPage;

  static const Color _accent = Color(0xFF37EC13);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.padding(context, 16),
        vertical: Responsive.padding(context, 12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: showHomeButtonOnFirstPage && currentPage == 0
                    ? IconButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(),
                            ),
                          );
                        },
                        tooltip: '홈으로 돌아가기',
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.home_rounded,
                          color: _accent,
                          size: Responsive.iconSize(context, 26),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: _accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 44),
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
                valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                minHeight: Responsive.fontSize(context, 4),
              );
            },
          ),
        ],
      ),
    );
  }
}
