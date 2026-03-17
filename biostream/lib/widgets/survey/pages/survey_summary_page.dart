import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';

class SurveySummaryPage extends StatelessWidget {
  const SurveySummaryPage({
    super.key,
    required this.isDark,
    required this.situationController,
    required this.situationTextMaxLength,
    required this.mainGoalsSummary,
    required this.sleepSummary,
    required this.uvSummary,
    required this.drinkingSmokingSummary,
    required this.stressRecoverySummary,
    required this.activitySummary,
    required this.skinSummary,
    required this.targetYearsSummary,
    required this.onSubmit,
  });

  final bool isDark;
  final TextEditingController situationController;
  final int situationTextMaxLength;
  final String mainGoalsSummary;
  final String sleepSummary;
  final String uvSummary;
  final String drinkingSmokingSummary;
  final String stressRecoverySummary;
  final String activitySummary;
  final String skinSummary;
  final String targetYearsSummary;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '참고할 상황 (선택)',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            '리포트에 반영해 주었으면 하는 상황이나 특성을 간단히 적어주세요. 비워두어도 됩니다.',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
          SizedBox(height: Responsive.padding(context, 12)),
          TextField(
            controller: situationController,
            maxLength: situationTextMaxLength,
            maxLines: 3,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: '예: 야근이 많아 새벽에 자요. 3개월 뒤 중요한 일이 있어요.',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2C16) : Colors.white,
              contentPadding: EdgeInsets.all(Responsive.padding(context, 16)),
            ),
          ),
          SizedBox(height: Responsive.padding(context, 24)),
          Text(
            '입력 요약',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 28),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: Responsive.padding(context, 24)),
          _summaryCard(context, title: '주요 목표', content: mainGoalsSummary),
          SizedBox(height: Responsive.padding(context, 16)),
          _summaryCard(context, title: '수면 패턴', content: sleepSummary),
          SizedBox(height: Responsive.padding(context, 16)),
          _summaryCard(context, title: '자외선 노출', content: uvSummary),
          SizedBox(height: Responsive.padding(context, 16)),
          _summaryCard(
            context,
            title: '음주 및 흡연',
            content: drinkingSmokingSummary,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _summaryCard(
            context,
            title: '스트레스 및 회복',
            content: stressRecoverySummary,
          ),
          SizedBox(height: Responsive.padding(context, 16)),
          _summaryCard(context, title: '활동 및 대사', content: activitySummary),
          SizedBox(height: Responsive.padding(context, 16)),
          _summaryCard(context, title: '피부 상태', content: skinSummary),
          SizedBox(height: Responsive.padding(context, 16)),
          _summaryCard(context, title: '목표 연도', content: targetYearsSummary),
          SizedBox(height: Responsive.padding(context, 32)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37EC13),
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.padding(context, 18),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                '제출하기',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2C16) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF37EC13),
            ),
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            content,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
