import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class LoginSocialSection extends StatelessWidget {
  const LoginSocialSection({
    super.key,
    required this.isDark,
    required this.onKakaoLogin,
  });

  final bool isDark;
  final VoidCallback onKakaoLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: Responsive.padding(context, 32)),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[200],
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 12),
              ),
              child: Text(
                'SNS 계정으로 간편 로그인',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[200],
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.padding(context, 32)),
        Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onKakaoLogin,
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                width: Responsive.fontSize(context, 48),
                height: Responsive.fontSize(context, 48),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE500),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: Size(
                      Responsive.iconSize(context, 24),
                      Responsive.iconSize(context, 24),
                    ),
                    painter: _KakaoIconPainter(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LoginFooterSection extends StatelessWidget {
  const LoginFooterSection({
    super.key,
    required this.isDark,
    required this.horizontalPadding,
    required this.onSignUp,
  });

  final bool isDark;
  final double horizontalPadding;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: TextButton(
        onPressed: onSignUp,
        style: TextButton.styleFrom(
          foregroundColor: isDark ? Colors.grey[400] : Colors.grey[500],
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
            children: const [
              TextSpan(text: '계정이 없으신가요? '),
              TextSpan(
                text: '회원가입',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF37EC13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KakaoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF191919)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.125)
      ..cubicTo(
        size.width * 0.2917,
        size.height * 0.125,
        size.width * 0.1667,
        size.height * 0.2413,
        size.width * 0.1667,
        size.height * 0.385,
      )
      ..cubicTo(
        size.width * 0.1667,
        size.height * 0.4683,
        size.width * 0.2179,
        size.height * 0.5413,
        size.width * 0.2979,
        size.height * 0.5896,
      )
      ..lineTo(size.width * 0.2596, size.height * 0.7325)
      ..cubicTo(
        size.width * 0.2563,
        size.height * 0.7433,
        size.width * 0.2704,
        size.height * 0.7558,
        size.width * 0.2808,
        size.height * 0.7463,
      )
      ..lineTo(size.width * 0.4567, size.height * 0.6296)
      ..cubicTo(
        size.width * 0.465,
        size.height * 0.6258,
        size.width * 0.475,
        size.height * 0.6258,
        size.width * 0.5,
        size.height * 0.6296,
      )
      ..cubicTo(
        size.width * 0.7083,
        size.height * 0.6296,
        size.width * 0.8333,
        size.height * 0.5133,
        size.width * 0.8333,
        size.height * 0.3696,
      )
      ..cubicTo(
        size.width * 0.8333,
        size.height * 0.2258,
        size.width * 0.7083,
        size.height * 0.125,
        size.width * 0.5,
        size.height * 0.125,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
