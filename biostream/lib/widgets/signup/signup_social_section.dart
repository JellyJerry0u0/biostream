import 'package:flutter/material.dart';

import '../../utils/responsive.dart';

class SignUpSocialSection extends StatelessWidget {
  const SignUpSocialSection({
    super.key,
    required this.isDark,
    required this.onKakaoTap,
  });

  final bool isDark;
  final VoidCallback onKakaoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color:
                    isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF),
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.padding(context, 16),
              ),
              child: Text(
                'Or continue with',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFF8FC985)
                      : const Color(0xFF599A4C),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color:
                    isDark ? const Color(0xFF2A4225) : const Color(0xFFD3E7CF),
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.padding(context, 24)),
        Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onKakaoTap,
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                width: Responsive.fontSize(context, 56),
                height: Responsive.fontSize(context, 56),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE500),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2A4225)
                        : const Color(0xFFD3E7CF),
                    width: 1,
                  ),
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

class _KakaoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3C1E1E)
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
