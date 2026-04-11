import 'package:flutter/foundation.dart';

/// 코치 탭 미확인 메시지 — 하단 네비 빨간 점
class CoachChatBadge {
  CoachChatBadge._();

  static final ValueNotifier<bool> unread = ValueNotifier<bool>(false);

  static void markUnread() => unread.value = true;

  static void clearUnread() => unread.value = false;
}
