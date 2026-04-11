import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_config.dart';
import 'authorized_http.dart';
import '../firebase_options.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'coach_chat_badge.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final AuthorizedHttp _authHttp = AuthorizedHttp();
  static const String _outdoorPromptType = 'outdoor_prompt';
  static const String _coachChatNudgeType = 'coach_chat_nudge';
  static const String _outdoorActionYes = 'outdoor_yes';
  static const String _outdoorActionNo = 'outdoor_no';
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
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
        _maybeMarkCoachUnreadFromFcm(message.data);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleFcmOpenNavigation(message.data);
      });

      final coldStartMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (coldStartMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleFcmOpenNavigation(coldStartMessage.data);
        });
      }

      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ FCM 초기화 실패: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails!.notificationResponse;
      if (response != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationResponse(response);
        });
      }
    }

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _handleNotificationResponse(
      NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final t = (data['type'] ?? '').toString();
    if (t == _coachChatNudgeType) {
      CoachTabLauncher.openChatTab();
      return;
    }
    if (t != _outdoorPromptType) {
      return;
    }

    String answer = 'unknown';
    final actionId = response.actionId ?? '';
    if (actionId == _outdoorActionYes) {
      answer = 'yes';
    } else if (actionId == _outdoorActionNo) {
      answer = 'no';
    } else if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      // 알림 본문 탭으로 앱이 열렸을 때는 불확실 응답으로 저장.
      answer = 'unknown';
    }

    final date = (data['date'] ?? '').toString();
    if (date.isEmpty) {
      return;
    }
    final stepsSnapshot = data['stepsSnapshot'] is int
        ? data['stepsSnapshot'] as int
        : int.tryParse('${data['stepsSnapshot']}') ?? 0;

    await _submitOutdoorPromptResponse(
      date: date,
      answer: answer,
      stepsSnapshot: stepsSnapshot,
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

  /// 내 정보 > 알림 설정 팝업용 — 현재 OS·FCM 기준 권한 상태 (새 권한 요청은 하지 않음).
  Future<PushPermissionSettingsSnapshot> loadPushPermissionSnapshot() async {
    if (kIsWeb) {
      return const PushPermissionSettingsSnapshot(
        platformSupported: false,
        alertsLikelyEnabled: false,
        statusLine: '이 플랫폼에서는 앱 푸시를 사용할 수 없습니다.',
        detailLine: '',
        showRequestButton: false,
        showSystemSettingsHint: false,
      );
    }
    if (!_isFcmSupportedPlatform()) {
      return const PushPermissionSettingsSnapshot(
        platformSupported: false,
        alertsLikelyEnabled: false,
        statusLine: '이 기기에서는 푸시 알림을 지원하지 않습니다.',
        detailLine: '',
        showRequestButton: false,
        showSystemSettingsHint: false,
      );
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Firebase 초기화(설정 조회): $e');
      return const PushPermissionSettingsSnapshot(
        platformSupported: true,
        alertsLikelyEnabled: false,
        statusLine: '알림 상태를 확인할 수 없습니다.',
        detailLine: '앱을 다시 시작한 뒤 다시 시도해 주세요.',
        showRequestButton: true,
        showSystemSettingsHint: true,
      );
    }

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final auth = settings.authorizationStatus;

    PermissionStatus? androidNotif;
    if (defaultTargetPlatform == TargetPlatform.android) {
      androidNotif = await Permission.notification.status;
    }

    final enabled = _alertsLikelyEnabled(auth, androidNotif);
    final statusLine = _statusLineKo(auth, androidNotif, enabled);
    final onlySettings =
        (defaultTargetPlatform == TargetPlatform.android &&
            androidNotif?.isPermanentlyDenied == true) ||
        (defaultTargetPlatform == TargetPlatform.iOS &&
            auth == AuthorizationStatus.denied);
    final showRequest = !enabled && !onlySettings;

    return PushPermissionSettingsSnapshot(
      platformSupported: true,
      alertsLikelyEnabled: enabled,
      statusLine: statusLine,
      detailLine: _coachPushDetailLineKo(enabled),
      showRequestButton: showRequest,
      showSystemSettingsHint: !enabled,
    );
  }

  /// 시스템 대화상자로 알림 권한 재요청(Firebase + Android 13+ 런타임 권한).
  Future<PushPermissionSettingsSnapshot> requestPushPermissionAgain() async {
    if (!_isFcmSupportedPlatform() || kIsWeb) {
      return loadPushPermissionSnapshot();
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Firebase 초기화(권한 요청): $e');
      return loadPushPermissionSnapshot();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final current = await Permission.notification.status;
      if (!current.isGranted) {
        await Permission.notification.request();
      }
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await syncTokenToServer();
    return loadPushPermissionSnapshot();
  }

  Future<bool> openSystemAppSettings() => openAppSettings();

  static bool _alertsLikelyEnabled(
    AuthorizationStatus auth,
    PermissionStatus? androidNotif,
  ) {
    if (defaultTargetPlatform == TargetPlatform.android &&
        androidNotif != null) {
      return androidNotif.isGranted;
    }
    return auth == AuthorizationStatus.authorized ||
        auth == AuthorizationStatus.provisional;
  }

  static String _statusLineKo(
    AuthorizationStatus auth,
    PermissionStatus? androidNotif,
    bool enabled,
  ) {
    if (enabled) {
      return '알림이 허용된 상태입니다.';
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        androidNotif != null) {
      if (androidNotif.isPermanentlyDenied) {
        return '알림이 꺼져 있거나 «다시 묻지 않음»으로 거절된 상태입니다.';
      }
      if (androidNotif.isDenied) {
        return '알림 권한이 아직 허용되지 않았습니다.';
      }
    }
    switch (auth) {
      case AuthorizationStatus.denied:
        return '알림이 시스템에서 거부된 상태입니다.';
      case AuthorizationStatus.notDetermined:
        return '알림 권한을 아직 선택하지 않았습니다.';
      case AuthorizationStatus.provisional:
      case AuthorizationStatus.authorized:
        return '알림이 허용된 상태입니다.';
    }
  }

  static String _coachPushDetailLineKo(bool enabled) {
    if (enabled) {
      return '코치가 생활 기록을 반영해 보내는 메시지(넛지), 리포트·야외 확인 등 알림을 받을 수 있어요. '
          '받지 않으려면 기기 설정에서 알림을 끄면 됩니다.';
    }
    return '코치 넛지·리포트 알림을 받으려면 아래에서 알림을 허용해 주세요. '
        '한번 거부했다면 「시스템 설정 열기」에서 BioStream 알림을 켜 주세요.';
  }

  Future<void> _registerToken(String fcmToken) async {
    try {
      if (!await _authHttp.hasAnyCredential()) {
        debugPrint('ℹ️ JWT 없음: FCM 토큰 등록 보류');
        return;
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _authHttp.post(
        Uri.parse('$origin/api/fcm/token'),
        headers: {
          'Content-Type': 'application/json',
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

  /// 오늘 첫 스냅샷 저장 후 코치 메시지가 준비되면 챗봇으로 유도
  void _maybeMarkCoachUnreadFromFcm(Map<String, dynamic> data) {
    final t = (data['type'] ?? '').toString();
    if (t == _coachChatNudgeType) {
      CoachChatBadge.markUnread();
    }
  }

  void _handleFcmOpenNavigation(Map<String, dynamic> data) {
    final t = (data['type'] ?? '').toString();
    if (t == _coachChatNudgeType) {
      CoachTabLauncher.openChatTab();
    }
  }

  Future<void> showCoachSnapshotNudge() async {
    if (!_initialized) {
      await initialize();
    }
    CoachChatBadge.markUnread();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'report_notifications',
        'Report Notifications',
        channelDescription: '건강 리포트 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    final payload = jsonEncode({'type': _coachChatNudgeType});
    await _localNotifications.show(
      92001,
      'Skin Coach',
      '오늘 생활 기록을 반영한 코치 메시지가 있어요. 탭하면 챗봇에서 볼 수 있어요.',
      details,
      payload: payload,
    );
  }

  Future<void> showOutdoorPrompt({
    required String date,
    required int stepsSnapshot,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'report_notifications',
        'Report Notifications',
        channelDescription: '건강 리포트 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            _outdoorActionYes,
            '예',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            _outdoorActionNo,
            '아니오',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    );

    final payload = jsonEncode({
      'type': _outdoorPromptType,
      'date': date,
      'stepsSnapshot': stepsSnapshot,
    });

    await _localNotifications.show(
      date.hashCode ^ stepsSnapshot,
      '야외 활동 확인',
      '지금 야외에 계신가요?',
      details,
      payload: payload,
    );
  }

  Future<void> _submitOutdoorPromptResponse({
    required String date,
    required String answer,
    required int stepsSnapshot,
  }) async {
    try {
      if (!await _authHttp.hasAnyCredential()) {
        return;
      }

      final origin = await ApiConfig.getBaseOrigin();
      final response = await _authHttp.post(
        Uri.parse('$origin/api/v1/outdoor-check-response'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': date,
          'answer': answer,
          'stepsSnapshot': stepsSnapshot,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('⚠️ 야외 활동 응답 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ 야외 활동 응답 저장 오류: $e');
    }
  }
}

/// [NotificationService.loadPushPermissionSnapshot] 결과.
class PushPermissionSettingsSnapshot {
  const PushPermissionSettingsSnapshot({
    required this.platformSupported,
    required this.alertsLikelyEnabled,
    required this.statusLine,
    required this.detailLine,
    required this.showRequestButton,
    required this.showSystemSettingsHint,
  });

  final bool platformSupported;
  final bool alertsLikelyEnabled;
  final String statusLine;
  final String detailLine;
  final bool showRequestButton;
  final bool showSystemSettingsHint;
}
