import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lifestyle_service.dart';
import 'notification_service.dart';

class UvPromptService {
  UvPromptService({
    required LifestyleService lifestyleService,
    required NotificationService notificationService,
  })  : _lifestyleService = lifestyleService,
        _notificationService = notificationService;

  final LifestyleService _lifestyleService;
  final NotificationService _notificationService;

  static const int _stepThreshold = 2500;
  static const int _dailyPromptLimit = 3;
  static const Duration _cooldown = Duration(hours: 2);
  static const String _lastPromptEpochMsKey = 'uv_last_prompt_epoch_ms';
  static const String _dailyPromptCountPrefix = 'uv_daily_prompt_count_';

  Future<void> maybeAskOutdoorPrompt() async {
    try {
      final now = DateTime.now();
      // UV 노출 관점 질문이므로 야간에는 질문하지 않습니다.
      if (now.hour < 8 || now.hour > 18) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final today = now.toIso8601String().split('T').first;
      final dayCountKey = '$_dailyPromptCountPrefix$today';
      final todayCount = prefs.getInt(dayCountKey) ?? 0;
      if (todayCount >= _dailyPromptLimit) {
        return;
      }

      final lastEpoch = prefs.getInt(_lastPromptEpochMsKey);
      if (lastEpoch != null) {
        final diff =
            now.difference(DateTime.fromMillisecondsSinceEpoch(lastEpoch));
        if (diff < _cooldown) {
          return;
        }
      }

      final health = await _lifestyleService.getTodayHealthData();
      if (health['success'] != true) {
        return;
      }
      final data = health['data'];
      if (data is! Map<String, dynamic>) {
        return;
      }

      final steps = _toInt(data['steps']);
      if (steps < _stepThreshold) {
        return;
      }

      await _notificationService.showOutdoorPrompt(
        date: today,
        stepsSnapshot: steps,
      );

      await prefs.setInt(_lastPromptEpochMsKey, now.millisecondsSinceEpoch);
      await prefs.setInt(dayCountKey, todayCount + 1);
      debugPrint('✅ UV 야외 확인 알림 표시: steps=$steps');
    } catch (e) {
      debugPrint('⚠️ UV 야외 확인 알림 처리 실패: $e');
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
