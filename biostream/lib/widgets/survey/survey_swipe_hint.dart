import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class SurveySwipeHint extends StatelessWidget {
  const SurveySwipeHint({
    super.key,
    required this.isDark,
    required this.onDismiss,
  });

  final bool isDark;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 32)),
            padding: EdgeInsets.all(Responsive.padding(context, 24)),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2C16) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swipe,
                  size: Responsive.iconSize(context, 48),
                  color: const Color(0xFF37EC13),
                ),
                SizedBox(height: Responsive.padding(context, 16)),
                Text(
                  '좌우로 넘겨서\n설문을 완료해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: Responsive.padding(context, 8)),
                Text(
                  '터치하여 닫기',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 12),
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
