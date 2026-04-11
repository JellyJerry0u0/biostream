import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class ResultHealthReportSection extends StatelessWidget {
  final bool isDark;
  final bool isGenerating;
  final Widget? reportContent;

  const ResultHealthReportSection({
    super.key,
    required this.isDark,
    required this.isGenerating,
    required this.reportContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.padding(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              'AI Skin Health Report',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 24),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF101B0D),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          if (isGenerating)
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF37EC13),
                  ),
                  SizedBox(height: Responsive.padding(context, 16)),
                  Text(
                    'AI가 건강 리포트를 생성하고 있습니다...',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 14),
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else if (reportContent != null)
            reportContent!,
        ],
      ),
    );
  }
}
