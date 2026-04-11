import 'dart:ui';

import 'package:flutter/material.dart';

/// 인트로 블러·안내 카드. 탭 시 서서히 걷히고, 스냅샷 생김으로 게이트만 꺼질 때도 동일 애니메이션.
class TodayMeLifestyleIntroLayer extends StatefulWidget {
  const TodayMeLifestyleIntroLayer({
    super.key,
    required this.showIntroGate,
    required this.onIntroDismissed,
    required this.primaryColor,
    required this.child,
    this.introCardText =
        '오늘의 생활습관을 저장하면\n주간 대시보드를 확인할 수 있어요.',
  });

  final bool showIntroGate;
  final VoidCallback onIntroDismissed;
  final Color primaryColor;
  final Widget child;
  final String introCardText;

  @override
  State<TodayMeLifestyleIntroLayer> createState() =>
      _TodayMeLifestyleIntroLayerState();
}

class _TodayMeLifestyleIntroLayerState extends State<TodayMeLifestyleIntroLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late CurvedAnimation _blurT;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _blurT = CurvedAnimation(
      parent: _ac,
      curve: Curves.easeInOutCubic,
    );
    if (widget.showIntroGate) {
      _ac.value = 1.0;
    }
  }

  @override
  void dispose() {
    _blurT.dispose();
    _ac.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TodayMeLifestyleIntroLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showIntroGate && !oldWidget.showIntroGate) {
      _ac.value = 1.0;
    } else if (!widget.showIntroGate && oldWidget.showIntroGate) {
      if (_ac.value > 0.02) {
        _ac.reverse();
      }
    }
  }

  Future<void> _onCardTap() async {
    await _ac.reverse();
    if (mounted) widget.onIntroDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) {
        final t = _blurT.value;
        final tVisual = widget.showIntroGate &&
                _ac.status != AnimationStatus.reverse &&
                _ac.status != AnimationStatus.dismissed
            ? 1.0
            : t;
        final layering =
            t > 0.008 || _ac.isAnimating || widget.showIntroGate;
        if (!layering) {
          return widget.child;
        }

        final sigma = 4.0 * tVisual;
        final contentOpacity = (1.0 - 0.48 * tVisual).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: Opacity(
                  opacity: contentOpacity,
                  child: AbsorbPointer(
                    absorbing: tVisual > 0.06,
                    child: widget.child,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: tVisual < 0.03,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.35,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1A3D2E).withValues(alpha: 0.045 * tVisual),
                      ],
                      stops: const [0.42, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: tVisual < 0.03,
                child: Center(
                  child: Opacity(
                    opacity: tVisual,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        elevation: 18 * tVisual,
                        shadowColor: Colors.black.withValues(alpha: 0.18 * tVisual),
                        borderRadius: BorderRadius.circular(32),
                        color: Colors.white,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: widget.primaryColor.withValues(
                                alpha: 0.2 + 0.15 * tVisual,
                              ),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Color.lerp(
                                  Colors.white,
                                  widget.primaryColor,
                                  0.06,
                                )!,
                              ],
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.showIntroGate ? _onCardTap : null,
                              borderRadius: BorderRadius.circular(32),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 22,
                                ),
                                child: Text(
                                  widget.introCardText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF102217),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
