import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../firebase_options.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    'report_notifications',
    'Report Notifications',
    description: '건강 리포트 알림 채널',
    importance: Importance.high,
  );
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool _isFcmSupportedPlatform() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    if (!_isFcmSupportedPlatform()) {
      debugPrint('ℹ️ 현재 플랫폼에서는 FCM 토큰 발급을 지원하지 않습니다.');
      _initialized = true;
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('⚠️ Firebase 초기화 실패: $e');
      return;
    }

    try {
      await _initializeLocalNotifications();

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 FCM permission: ${settings.authorizationStatus}');

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _registerToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((message) async {
        await _showForegroundNotification(message);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ FCM 초기화 실패: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initializationSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'report_notifications',
        'Report Notifications',
        channelDescription: '건강 리포트 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title ?? '알림',
      notification.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> syncTokenToServer() async {
    if (!_isFcmSupportedPlatform()) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('⚠️ FCM 토큰 동기화 실패: $e');
    }
  }

  Future<void> _registerToken(String fcmToken) async {
    try {
      final jwt = await _storage.read(key: 'jwt_token');
      if (jwt == null || jwt.isEmpty) {
        debugPrint('ℹ️ JWT 없음: FCM 토큰 등록 보류');
        return;
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await http.post(
        Uri.parse('$origin/api/fcm/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'token': fcmToken,
          'platform': defaultTargetPlatform.name,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ FCM 토큰 등록 성공');
      } else {
        debugPrint('⚠️ FCM 토큰 등록 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ FCM 토큰 등록 오류: $e');
    }
  }
}
