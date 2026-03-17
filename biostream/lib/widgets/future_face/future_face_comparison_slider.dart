import 'package:flutter/material.dart';

class FutureFaceComparisonSlider extends StatelessWidget {
  const FutureFaceComparisonSlider({
    super.key,
    required this.isDark,
    required this.isLoading,
    required this.currentImageUrl,
    required this.futureImageUrl,
    required this.imageError,
    required this.sliderRatio,
    required this.primaryColor,
    required this.onSliderRatioChanged,
  });

  final bool isDark;
  final bool isLoading;
  final String? currentImageUrl;
  final String? futureImageUrl;
  final String? imageError;
  final double sliderRatio;
  final Color primaryColor;
  final ValueChanged<double> onSliderRatioChanged;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AspectRatio(
        aspectRatio: 3 / 4,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentImageUrl == null || futureImageUrl == null) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEAEAEA),
          ),
          child: Center(
            child: Text(
              imageError ?? '최근 리포트의 비교 이미지를 찾을 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dividerX = width * sliderRatio;

        return AspectRatio(
          aspectRatio: 3 / 4,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final localX = details.localPosition.dx.clamp(0.0, width);
              onSliderRatioChanged(localX / width);
            },
            onTapDown: (details) {
              final localX = details.localPosition.dx.clamp(0.0, width);
              onSliderRatioChanged(localX / width);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(futureImageUrl!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: dividerX,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: sliderRatio,
                        child: SizedBox(
                          width: width,
                          child: Image.network(currentImageUrl!,
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: dividerX - 1,
                    child: Container(
                      width: 2,
                      color: primaryColor,
                    ),
                  ),
                  Positioned(
                    left: dividerX - 22,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.6),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.unfold_more,
                          color: Color(0xFF102217),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _labelChip('현재', Colors.white),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _labelChip('미래 예측', primaryColor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _labelChip(String text, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF102217).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
