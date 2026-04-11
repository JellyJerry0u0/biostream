import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

/// 설문 제출 후 GPU skin-edit 등 대기용 — 반투명 배경 + 카드 + 스피너
void showSurveyAiGeneratingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => const _SurveyAiGeneratingDialogContent(),
  );
}

class _SurveyAiGeneratingDialogContent extends StatelessWidget {
  const _SurveyAiGeneratingDialogContent();

  static const _accent = Color(0xFF37EC13);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E3318) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1F1A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF5C6560);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.82,
          constraints: const BoxConstraints(maxWidth: 320),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.padding(context, 28),
            vertical: Responsive.padding(context, 32),
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE8EDE8),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: Responsive.padding(context, 48),
                height: Responsive.padding(context, 48),
                child: const CircularProgressIndicator(
                  strokeWidth: 3.2,
                  color: _accent,
                  strokeCap: StrokeCap.round,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 22)),
              Text(
                'AI 이미지 생성 중…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 17),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: titleColor,
                  height: 1.25,
                ),
              ),
              SizedBox(height: Responsive.padding(context, 10)),
              Text(
                '설문에 맞춰 이미지를 준비하고 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
