import 'package:flutter/material.dart';

import '../../../utils/responsive.dart';

/// 마지막 설문 페이지 — 참고사항 입력 + 제출만 (다른 섹션과 동일한 타이포·레이아웃)
class SurveySummaryPage extends StatelessWidget {
  const SurveySummaryPage({
    super.key,
    required this.isDark,
    required this.situationController,
    required this.situationTextMaxLength,
    required this.onSubmit,
    this.submitBusy = false,
  });

  final bool isDark;
  final TextEditingController situationController;
  final int situationTextMaxLength;
  final VoidCallback onSubmit;
  final bool submitBusy;

  static const Color _accent = Color(0xFF37EC13);

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return SingleChildScrollView(
      padding: EdgeInsets.all(Responsive.padding(context, 24)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '참고사항 (선택)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 28),
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  height: 1.2,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 10)),
              Text(
                '리포트에 반영해 주었으면 하는 상황이나 특성을 간단히 적어주세요. 비워두어도 됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  color: subtitleColor,
                  height: 1.45,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 32)),
              TextField(
                controller: situationController,
                maxLength: situationTextMaxLength,
                maxLines: 5,
                minLines: 3,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 15),
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: '예: 야근이 많아 새벽에 자요. 3개월 뒤 중요한 일이 있어요.',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                    fontSize: Responsive.fontSize(context, 14),
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A2C16) : Colors.white,
                  contentPadding: EdgeInsets.all(Responsive.padding(context, 18)),
                ),
              ),
              SizedBox(height: Responsive.padding(context, 28)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitBusy ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: _accent.withValues(alpha: 0.45),
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.padding(context, 18),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    submitBusy ? '처리 중…' : '제출하기',
                    style: TextStyle(
                      fontSize: Responsive.fontSize(context, 17),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
