import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class ResultActionButtons extends StatelessWidget {
  final bool isDark;
  final bool showNotionButton;
  /// AI 리포트 본문을 펼친 뒤에만 true (View Action Plan 노출).
  final bool showViewActionPlan;
  final VoidCallback onViewActionPlan;
  final VoidCallback onOpenNotion;

  const ResultActionButtons({
    super.key,
    required this.isDark,
    required this.showNotionButton,
    this.showViewActionPlan = true,
    required this.onViewActionPlan,
    required this.onOpenNotion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showViewActionPlan) ...[
          SizedBox(
            width: double.infinity,
            height: Responsive.fontSize(context, 56),
            child: ElevatedButton(
              onPressed: onViewActionPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37EC13),
                foregroundColor: const Color(0xFF101B0D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
                elevation: 0,
                shadowColor: const Color(0xFF37EC13).withValues(alpha: 0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Action Plan',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: Responsive.padding(context, 8)),
                  Icon(
                    Icons.arrow_forward,
                    size: Responsive.iconSize(context, 20),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.padding(context, 12)),
        ],
        if (showNotionButton)
          SizedBox(
            width: double.infinity,
            height: Responsive.fontSize(context, 56),
            child: ElevatedButton.icon(
              onPressed: onOpenNotion,
              icon: Icon(
                Icons.description_outlined,
                size: Responsive.iconSize(context, 20),
              ),
              label: Text(
                'Notion 바로가기',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFF2A4025) : Colors.white,
                foregroundColor:
                    isDark ? Colors.white : const Color(0xFF101B0D),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey[200]!,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
                elevation: 0,
              ),
            ),
          ),
        if (showNotionButton) SizedBox(height: Responsive.padding(context, 12)),
      ],
    );
  }
}
