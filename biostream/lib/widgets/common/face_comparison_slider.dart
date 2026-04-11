import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/api_config.dart';

class LeftSplitClipper extends CustomClipper<Rect> {
  LeftSplitClipper({required this.splitX});

  final double splitX;

  @override
  Rect getClip(Size size) {
    final w = splitX.clamp(0.0, size.width);
    return Rect.fromLTWH(0, 0, w, size.height);
  }

  @override
  bool shouldReclip(covariant LeftSplitClipper old) => old.splitX != splitX;
}

class AuthCoverImage extends StatefulWidget {
  const AuthCoverImage({super.key, required this.url});

  final String url;

  @override
  State<AuthCoverImage> createState() => _AuthCoverImageState();
}

class _AuthCoverImageState extends State<AuthCoverImage> {
  static const _storage = FlutterSecureStorage();
  Map<String, String>? _headers;

  static int _effectivePort(Uri u) {
    if (u.hasPort) return u.port;
    return u.scheme == 'https' ? 443 : 80;
  }

  static bool _needsApiAuth(String url, String origin) {
    try {
      final u = Uri.parse(url);
      final o = Uri.parse(origin);
      if (u.scheme != o.scheme) return false;
      if (u.host.toLowerCase() != o.host.toLowerCase()) return false;
      if (_effectivePort(u) != _effectivePort(o)) return false;
      return u.path.contains('/data/image/');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant AuthCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _prepare();
    }
  }

  Future<void> _prepare() async {
    final origin = await ApiConfig.getBaseOrigin();
    if (!_needsApiAuth(widget.url, origin)) {
      if (mounted) setState(() => _headers = const {});
      return;
    }
    final token = await _storage.read(key: 'jwt_token');
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      setState(() => _headers = {'Authorization': 'Bearer $token'});
    } else {
      setState(() => _headers = const {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_headers == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      headers: _headers!.isEmpty ? null : _headers,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: Colors.grey.shade800,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white54),
        ),
      ),
    );
  }
}

/// 원본(왼쪽 클립) / 생성(오른쪽 전체) 동일 스케일 비교, 드래그로 비율 조절
class FaceComparisonSlider extends StatelessWidget {
  const FaceComparisonSlider({
    super.key,
    required this.isDark,
    required this.isLoading,
    required this.leftImageUrl,
    required this.rightImageUrl,
    required this.imageError,
    required this.sliderRatio,
    required this.primaryColor,
    required this.onSliderRatioChanged,
    this.aspectRatio = 3 / 4,
    this.borderRadius = 18,
    this.leftLabel = '현재',
    this.rightLabel = '미래 예측',
    this.showEdgeLabels = true,
    this.handleIconColor = const Color(0xFF102217),
    this.emptyStateBorderRadius,
  });

  final bool isDark;
  final bool isLoading;
  final String? leftImageUrl;
  final String? rightImageUrl;
  final String? imageError;
  final double sliderRatio;
  final Color primaryColor;
  final ValueChanged<double> onSliderRatioChanged;
  final double aspectRatio;
  final double borderRadius;
  final String leftLabel;
  final String rightLabel;
  /// 사진 하단 좌·우 라벨 칩(글자 박스) 표시 여부
  final bool showEdgeLabels;
  final Color handleIconColor;
  /// 로딩/에러 플레이스홀더 모서리 (기본 [borderRadius])
  final double? emptyStateBorderRadius;

  @override
  Widget build(BuildContext context) {
    final emptyRadius = emptyStateBorderRadius ?? borderRadius;

    if (isLoading) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (leftImageUrl == null || rightImageUrl == null) {
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(emptyRadius),
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEAEAEA),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                imageError ?? '비교 이미지를 찾을 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final ratio = sliderRatio.clamp(0.02, 0.98);
        final dividerX = width * ratio;

        return AspectRatio(
          aspectRatio: aspectRatio,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              final localX = details.localPosition.dx.clamp(0.0, width);
              onSliderRatioChanged(localX / width);
            },
            onTapDown: (details) {
              final localX = details.localPosition.dx.clamp(0.0, width);
              onSliderRatioChanged(localX / width);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AuthCoverImage(url: rightImageUrl!),
                  ClipRect(
                    clipper: LeftSplitClipper(splitX: dividerX),
                    child: AuthCoverImage(url: leftImageUrl!),
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
                    left: dividerX - 24,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
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
                        child: Text(
                          'VS',
                          style: TextStyle(
                            color: handleIconColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showEdgeLabels) ...[
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _labelChip(leftLabel, Colors.white),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _labelChip(rightLabel, primaryColor),
                    ),
                  ],
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
