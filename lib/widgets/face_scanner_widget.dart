import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class FaceScannerWidget extends StatelessWidget {
  final AnimationController scanController;
  final bool isDark;

  const FaceScannerWidget({
    super.key,
    required this.scanController,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final size = Responsive.screenWidth(context) * 0.7;
    final maxSize = Responsive.fontSize(context, 280);
    final scannerSize = size > maxSize ? maxSize : size;

    return Center(
      child: SizedBox(
        width: scannerSize,
        height: scannerSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Background Glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF37EC13).withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF37EC13).withOpacity(0.3),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Main Frame with proper clipping
            ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Placeholder Face SVG
                    Center(
                      child: Opacity(
                        opacity: isDark ? 0.3 : 0.2,
                        child: CustomPaint(
                          size: Size(
                            Responsive.fontSize(context, 192),
                            Responsive.fontSize(context, 224),
                          ),
                          painter: _FacePlaceholderPainter(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    // Scanning Overlay Line
                    AnimatedBuilder(
                      animation: scanController,
                      builder: (context, child) {
                        final value = scanController.value;
                        final top = value * 100;
                        final opacity = value < 0.1
                            ? value / 0.1
                            : value > 0.9
                                ? (1 - value) / 0.1
                                : 1.0;

                        return Positioned(
                          top: top < 0 ? 0 : (top > 100 ? 100 : top),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFF37EC13)
                                  .withOpacity(opacity.clamp(0.0, 1.0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF37EC13)
                                      .withOpacity(0.8 * opacity.clamp(0.0, 1.0)),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Crosshairs
                    Positioned(
                      top: Responsive.padding(context, 24),
                      left: Responsive.padding(context, 24),
                      child: Container(
                        width: Responsive.fontSize(context, 32),
                        height: Responsive.fontSize(context, 32),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: const Color(0xFF37EC13),
                              width: 4,
                            ),
                            left: BorderSide(
                              color: const Color(0xFF37EC13),
                              width: 4,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: Responsive.padding(context, 24),
                      right: Responsive.padding(context, 24),
                      child: Container(
                        width: Responsive.fontSize(context, 32),
                        height: Responsive.fontSize(context, 32),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: const Color(0xFF37EC13),
                              width: 4,
                            ),
                            right: BorderSide(
                              color: const Color(0xFF37EC13),
                              width: 4,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: Responsive.padding(context, 24),
                      left: Responsive.padding(context, 24),
                      child: Container(
                        width: Responsive.fontSize(context, 32),
                        height: Responsive.fontSize(context, 32),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: const Color(0xFF37EC13),
                              width: 4,
                            ),
                            left: BorderSide(
                              color: const Color(0xFF37EC13),
                              width: 4,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: Responsive.padding(context, 24),
                      right: Responsive.padding(context, 24),
                      child: Container(
                        width: Responsive.fontSize(context, 32),
                        height: Responsive.fontSize(context, 32),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: const Color(0xFF37EC13),
                              width: 4,
                            ),
                            right: BorderSide(
                              color: const Color(0xFF37EC13),
                              width: 4,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Add Button Overlay - positioned outside to prevent clipping
            Positioned(
              bottom: -Responsive.padding(context, 20),
              child: Container(
                padding: EdgeInsets.all(Responsive.padding(context, 6)),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2E18) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Container(
                  padding: EdgeInsets.all(Responsive.padding(context, 12)),
                  decoration: const BoxDecoration(
                    color: Color(0xFF37EC13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_a_photo,
                    color: const Color(0xFF101B0D),
                    size: Responsive.iconSize(context, 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Face Placeholder Painter
class _FacePlaceholderPainter extends CustomPainter {
  final Color color;

  _FacePlaceholderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Face outline (oval)
    final faceRect = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.1,
      size.width * 0.8,
      size.height * 0.8,
    );
    canvas.drawOval(faceRect, paint);

    // Left eye (curved line, closed eye feeling)
    final leftEyePath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.46,
        size.width * 0.42,
        size.height * 0.42,
      );
    canvas.drawPath(leftEyePath, paint);

    // Right eye (curved line, closed eye feeling)
    final rightEyePath = Path()
      ..moveTo(size.width * 0.58, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.65,
        size.height * 0.46,
        size.width * 0.72,
        size.height * 0.42,
      );
    canvas.drawPath(rightEyePath, paint);

    // Mouth (smiling curved line)
    final mouthPath = Path()
      ..moveTo(size.width * 0.35, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.75,
        size.width * 0.65,
        size.height * 0.68,
      );
    canvas.drawPath(mouthPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

