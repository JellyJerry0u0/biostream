import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 앱 전역: 입력 필드 밖을 누르면 포커스 해제 + 키보드 숨김.
///
/// [GestureDetector]는 자식 [TextField]와 제스처 경쟁을 일으켜 **탭해도 키보드가 안 뜨는**
/// 경우가 있어, 제스처 아레나에 끼지 않는 [Listener] + 포인터 이후 프레임에서 hit test로 처리합니다.
/// (다른 앱과 같이: 포커스 있는 입력 밖 탭 → 키보드 내림)
class KeyboardDismissScope extends StatelessWidget {
  const KeyboardDismissScope({super.key, required this.child});

  final Widget? child;

  static bool _hitPathContainsEditable(HitTestResult result) {
    for (final HitTestEntry entry in result.path) {
      if (entry.target is RenderEditable) {
        return true;
      }
    }
    return false;
  }

  void _maybeDismissKeyboard(BuildContext context, Offset globalPosition) {
    final HitTestResult result = HitTestResult();
    final FlutterView view = View.maybeOf(context) ??
        WidgetsBinding.instance.platformDispatcher.views.first;
    WidgetsBinding.instance.hitTestInView(result, globalPosition, view.viewId);
    if (_hitPathContainsEditable(result)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _onPointerDown(BuildContext context, PointerDownEvent event) {
    // 같은 프레임에서 TextField가 먼저 포커스를 받도록, 판단은 다음 프레임에 맡김.
    // 단, 탭으로 다른 입력칸으로 포커스가 이동한 경우에는 절대 강제 dismiss 하지 않는다.
    final pos = event.position;
    final FocusNode? previousFocus = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final FocusNode? currentFocus = FocusManager.instance.primaryFocus;
      if (currentFocus != previousFocus) {
        return;
      }
      _maybeDismissKeyboard(context, pos);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _onPointerDown(context, e),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
