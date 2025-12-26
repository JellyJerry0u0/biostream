import 'package:flutter/material.dart';

class Responsive {
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static bool isSmallScreen(BuildContext context) {
    return screenWidth(context) < 360;
  }

  static bool isMediumScreen(BuildContext context) {
    final width = screenWidth(context);
    return width >= 360 && width < 768;
  }

  static bool isLargeScreen(BuildContext context) {
    return screenWidth(context) >= 768;
  }

  // 반응형 폰트 크기
  static double fontSize(BuildContext context, double baseSize) {
    final width = screenWidth(context);
    if (width < 360) {
      return baseSize * 0.85; // 작은 화면: 85%
    } else if (width >= 768) {
      return baseSize * 1.15; // 큰 화면: 115%
    }
    return baseSize; // 기본 크기
  }

  // 반응형 패딩
  static double padding(BuildContext context, double basePadding) {
    final width = screenWidth(context);
    if (width < 360) {
      return basePadding * 0.75; // 작은 화면: 75%
    } else if (width >= 768) {
      return basePadding * 1.25; // 큰 화면: 125%
    }
    return basePadding; // 기본 패딩
  }

  // 반응형 아이콘 크기
  static double iconSize(BuildContext context, double baseSize) {
    final width = screenWidth(context);
    if (width < 360) {
      return baseSize * 0.9;
    } else if (width >= 768) {
      return baseSize * 1.1;
    }
    return baseSize;
  }

  // 최대 너비 제한 (태블릿 등)
  static double maxContentWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width >= 768) {
      return 500; // 태블릿 이상에서는 최대 500px
    }
    return double.infinity; // 모바일에서는 전체 너비
  }
}
