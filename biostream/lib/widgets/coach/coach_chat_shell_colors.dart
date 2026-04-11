import 'package:flutter/material.dart';

import '../../models/coach_models.dart';

/// Quick(녹색) vs Coach(보라) 챗 셸 색 — [CoachEngine]에 따라 전환
abstract final class CoachChatShellColors {
  static const quickAccent = Color(0xFF37EC13);
  static const coachAccent = Color(0xFF7C4DFF);

  static bool _coach(CoachEngine e) => e == CoachEngine.coach;

  static Color accent(CoachEngine engine) =>
      _coach(engine) ? coachAccent : quickAccent;

  /// 밝은 액센트 위에 쓰는 거의 검정 글자색
  static Color onAccentFg(CoachEngine engine) =>
      _coach(engine) ? const Color(0xFF1A0D2E) : const Color(0xFF101B0D);

  static Color scaffoldBg({
    required bool isDark,
    required CoachEngine engine,
  }) {
    if (_coach(engine)) {
      return isDark ? const Color(0xFF181528) : const Color(0xFFF5F2FF);
    }
    return isDark ? const Color(0xFF132210) : const Color(0xFFF6F8F6);
  }

  static Color stripBg({
    required bool isDark,
    required CoachEngine engine,
  }) =>
      scaffoldBg(isDark: isDark, engine: engine).withValues(alpha: 0.95);

  static Color inputFieldShellDark(CoachEngine engine) =>
      _coach(engine) ? const Color(0xFF221C35) : const Color(0xFF1C2E18);

  static Color quickChipDark(CoachEngine engine) => inputFieldShellDark(engine);

  static Color userBubble(CoachEngine engine) => accent(engine);

  static Color assistantBubbleDark(CoachEngine engine) =>
      _coach(engine) ? const Color(0xFF231E35) : const Color(0xFF1C2E18);

  static Color avatarRingDark(CoachEngine engine) =>
      assistantBubbleDark(engine);

  static List<Color> emptyStateGradient(CoachEngine engine) {
    final a = accent(engine);
    return [
      a.withValues(alpha: 0.28),
      a.withValues(alpha: 0.04),
    ];
  }

  static Color emptyStateBorder(CoachEngine engine) =>
      accent(engine).withValues(alpha: 0.26);

  static Color habitPersonalizationCardBg({
    required bool isDark,
    required CoachEngine engine,
  }) {
    if (_coach(engine)) {
      return isDark ? const Color(0xFF161525) : const Color(0xFFFAF9FF);
    }
    return isDark ? const Color(0xFF121A15) : const Color(0xFFFAFCFA);
  }

  static Color habitReasonBgLight(CoachEngine engine) =>
      _coach(engine) ? const Color(0xFFF4F2FF) : const Color(0xFFF4F7F4);

  static Color habitTileStrokeLight(CoachEngine engine) =>
      _coach(engine) ? const Color(0xFFE8E4F4) : const Color(0xFFEEF2EE);
}
