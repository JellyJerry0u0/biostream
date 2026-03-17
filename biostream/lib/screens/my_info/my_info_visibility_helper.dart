import 'package:flutter/material.dart';

import '../../widgets/app_bottom_nav_bar.dart';

class MyInfoVisibilityUpdate {
  const MyInfoVisibilityUpdate({
    this.visibilityValue,
    this.showBlankCanvas,
    this.shouldForward = false,
    this.shouldReverse = false,
    this.shouldPlayIntro = false,
    this.reverseEpoch,
  });

  final double? visibilityValue;
  final bool? showBlankCanvas;
  final bool shouldForward;
  final bool shouldReverse;
  final bool shouldPlayIntro;
  final int? reverseEpoch;
}

class MyInfoVisibilityHelper {
  bool _wasVisibleInShell = false;
  bool _didInitVisibility = false;
  bool _showBlankCanvas = false;
  int _visibilityEpoch = 0;

  MyInfoVisibilityUpdate handleVisibilityChange(bool isVisibleNow) {
    if (!_didInitVisibility) {
      _didInitVisibility = true;
      _wasVisibleInShell = isVisibleNow;
      _showBlankCanvas = !isVisibleNow;
      return MyInfoVisibilityUpdate(
        visibilityValue: isVisibleNow ? 1 : 0,
        showBlankCanvas: _showBlankCanvas,
        shouldPlayIntro: isVisibleNow,
      );
    }

    if (isVisibleNow) {
      _visibilityEpoch++;
      final shouldHideBlank = _showBlankCanvas;
      _showBlankCanvas = false;
      final shouldPlayIntro = !_wasVisibleInShell;
      _wasVisibleInShell = true;
      return MyInfoVisibilityUpdate(
        showBlankCanvas: shouldHideBlank ? false : null,
        shouldForward: true,
        shouldPlayIntro: shouldPlayIntro,
      );
    }

    if (_wasVisibleInShell) {
      final epoch = ++_visibilityEpoch;
      _wasVisibleInShell = false;
      return MyInfoVisibilityUpdate(
        shouldReverse: true,
        reverseEpoch: epoch,
      );
    }

    _wasVisibleInShell = false;
    return const MyInfoVisibilityUpdate();
  }

  bool shouldShowBlankCanvasAfterReverse({
    required int epoch,
    required bool isVisibleNow,
  }) {
    if (epoch != _visibilityEpoch || isVisibleNow) {
      return false;
    }
    _showBlankCanvas = true;
    return true;
  }

  static bool isMyInfoScreenVisible(BuildContext context) {
    final shellScope = NavShellScope.maybeOf(context);
    if (shellScope == null) {
      return true;
    }
    return shellScope.activeTab == AppNavTab.myInfo;
  }
}
