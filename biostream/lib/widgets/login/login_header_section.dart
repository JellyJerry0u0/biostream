import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class LoginHeaderSection extends StatelessWidget {
  const LoginHeaderSection({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
  });

  final bool isDark;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: Responsive.padding(context, 48),
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: Responsive.padding(context, 24),
      ),
      child: Column(
        children: [
          Container(
            width: Responsive.fontSize(context, 96),
            height: Responsive.fontSize(context, 96),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  const Color(0xFF37EC13).withValues(alpha: 0.2),
                  const Color(0xFF37EC13).withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.face_3,
                    size: Responsive.fontSize(context, 48),
                    color: const Color(0xFF37EC13),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.padding(context, 24)),
          Text(
            'AI 피부 분석',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 30),
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF101B0D),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Responsive.padding(context, 8)),
          Text(
            '미래의 나를 만나는 시간,\n지금 바로 시작하세요.',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: isDark ? Colors.grey[400] : Colors.grey[500],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
