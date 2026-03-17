import 'package:flutter/material.dart';

class HomeRecentPredictionSection extends StatelessWidget {
  const HomeRecentPredictionSection({
    super.key,
    required this.primaryColor,
    required this.backgroundDarkColor,
    required this.gameCardColor,
    required this.originalImageUrl,
    required this.generatedImageUrl,
    required this.predictionPoint,
    required this.onOpenResult,
  });

  final Color primaryColor;
  final Color backgroundDarkColor;
  final Color gameCardColor;
  final String? originalImageUrl;
  final String? generatedImageUrl;
  final String? predictionPoint;
  final VoidCallback onOpenResult;

  @override
  Widget build(BuildContext context) {
    final hasOriginal =
        originalImageUrl != null && originalImageUrl!.isNotEmpty;
    final hasGenerated =
        generatedImageUrl != null && generatedImageUrl!.isNotEmpty;
    final hasPoint = predictionPoint != null && predictionPoint!.isNotEmpty;

    if (!hasOriginal && !hasGenerated && !hasPoint) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최근 노화 예측 결과',
              style: TextStyle(
                color: Color(0xFF102217),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: onOpenResult,
              child: Text(
                '전체 보기',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: gameCardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              _predictionImage(
                imageUrl: originalImageUrl,
                fallbackLabel: 'NOW',
              ),
              const SizedBox(width: 10),
              _predictionImage(
                imageUrl: generatedImageUrl,
                fallbackLabel: '+YEARS',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '예측 포인트',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasPoint ? predictionPoint! : '최근 예측 결과를 확인해보세요.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: onOpenResult,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: backgroundDarkColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text(
                          'AI 분석 리포트',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _predictionImage({
    required String? imageUrl,
    required String fallbackLabel,
  }) {
    return Container(
      width: 78,
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.white.withValues(alpha: 0.04),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              color: Colors.white.withValues(alpha: 0.04),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_outlined,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                fallbackLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
