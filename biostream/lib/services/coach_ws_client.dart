/// 코치 챗봇 WebSocket 클라이언트
/// - Authorization 토큰 포함
/// - 자동 재연결 (exponential backoff)
/// - 메시지 타입별 콜백 분기
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_config.dart';

/// WebSocket 이벤트 콜백
typedef WsEventCallback = void Function(Map<String, dynamic> data);

class CoachWsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 상태
  bool _isConnected = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempt = 8;
  Timer? _reconnectTimer;

  // 현재 세션
  String? sessionId;
  int? reportId;

  // 이벤트 콜백
  WsEventCallback? onStart;
  WsEventCallback? onDelta;
  WsEventCallback? onActions;
  WsEventCallback? onCitations;
  WsEventCallback? onMemoryUpdate;
  WsEventCallback? onModeInfo;
  WsEventCallback? onToolStatus;
  WsEventCallback? onCoachProgress;
  WsEventCallback? onGoalProposals;
  WsEventCallback? onHabitDomainChart;
  WsEventCallback? onHabitPersonalizationProposals;
  WsEventCallback? onDone;
  WsEventCallback? onError;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;

  bool get isConnected => _isConnected;

  /// 연결 시작
  Future<void> connect({String? sessionId, int? reportId}) async {
    this.sessionId = sessionId;
    this.reportId = reportId;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null || token.isEmpty) {
        debugPrint('[CoachWS] JWT 토큰 없음 - 연결 불가');
        return;
      }

      final origin = await ApiConfig.getBaseOrigin();
      // http → ws, https → wss
      final wsOrigin = origin
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      // 쿼리 파라미터 구성
      final params = <String, String>{'token': token};
      if (sessionId != null) params['session_id'] = sessionId!;
      if (reportId != null) params['report_id'] = reportId.toString();

      final uri = Uri.parse('$wsOrigin/ws/coach').replace(queryParameters: params);
      debugPrint('[CoachWS] 연결 시도: $uri');

      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onDone: _onConnectionClosed,
        onError: _onConnectionError,
      );

      _isConnected = true;
      _reconnectAttempt = 0;
      onConnected?.call();
      debugPrint('[CoachWS] 연결 성공');
    } catch (e) {
      debugPrint('[CoachWS] 연결 실패: $e');
      _scheduleReconnect();
    }
  }

  /// 메시지 전송
  void send(Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) {
      debugPrint('[CoachWS] 연결 안 됨 - 메시지 무시');
      return;
    }
    final json = jsonEncode(data);
    _channel!.sink.add(json);
  }

  /// 사용자 메시지 전송
  void sendUserMessage(
    String message, {
    String mode = 'auto',
    String? engine,
  }) {
    send({
      'type': 'user_message',
      if (sessionId != null) 'session_id': sessionId,
      'message': message,
      if (reportId != null) 'report_id': reportId,
      'mode': mode,
      if (engine != null) 'engine': engine,
    });
  }

  /// 액션 이벤트 전송
  void sendAction(String actionId, {Map<String, dynamic>? payload}) {
    send({
      'type': 'action',
      if (sessionId != null) 'session_id': sessionId,
      'action_id': actionId,
      if (payload != null) 'payload': payload,
    });
  }

  /// Action Plan 초기화 요청 (result 화면에서 최초 진입 시)
  void sendActionPlanInit(List<int> newActionIds) {
    send({
      'type': 'action_plan_init',
      if (sessionId != null) 'session_id': sessionId,
      'new_action_ids': newActionIds,
    });
  }

  /// 모든 개인화 수락/거절 완료 시 마무리 요청
  void sendActionPlanComplete() {
    send({
      'type': 'action_plan_complete',
      if (sessionId != null) 'session_id': sessionId,
    });
  }

  /// 엔진 모드 전환 요청
  /// [context] `action_plan`이면 리포트 직후 플로우로 간주해 수동 코치 브리핑을 생략한다.
  void sendModeSwitch(String engine, {String? context}) {
    send({
      'type': 'mode_switch',
      'engine': engine,
      if (context != null) 'context': context,
    });
  }

  /// 연결 해제
  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  // ── 내부 핸들러 ──

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      // 세션 ID 업데이트
      if (data.containsKey('session_id')) {
        sessionId = data['session_id'] as String?;
      }

      switch (type) {
        case 'start':
          onStart?.call(data);
          break;
        case 'delta':
          onDelta?.call(data);
          break;
        case 'actions':
          onActions?.call(data);
          break;
        case 'citations':
          onCitations?.call(data);
          break;
        case 'memory_update':
          onMemoryUpdate?.call(data);
          break;
        case 'mode_info':
          onModeInfo?.call(data);
          break;
        case 'tool_status':
          onToolStatus?.call(data);
          break;
        case 'coach_progress':
          onCoachProgress?.call(data);
          break;
        case 'goal_proposals':
          onGoalProposals?.call(data);
          break;
        case 'habit_domain_chart':
          onHabitDomainChart?.call(data);
          break;
        case 'habit_personalization_proposals':
          onHabitPersonalizationProposals?.call(data);
          break;
        case 'done':
          onDone?.call(data);
          break;
        case 'error':
          onError?.call(data);
          break;
        default:
          debugPrint('[CoachWS] 알 수 없는 메시지 타입: $type');
      }
    } catch (e) {
      debugPrint('[CoachWS] 메시지 파싱 오류: $e');
    }
  }

  void _onConnectionClosed() {
    debugPrint('[CoachWS] 연결 닫힘');
    _isConnected = false;
    onDisconnected?.call();
    _scheduleReconnect();
  }

  void _onConnectionError(dynamic error) {
    debugPrint('[CoachWS] 연결 오류: $error');
    _isConnected = false;
    onDisconnected?.call();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectAttempt >= _maxReconnectAttempt) return;

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s ...
    final delay = Duration(seconds: (1 << _reconnectAttempt).clamp(1, 30));
    _reconnectAttempt++;
    debugPrint('[CoachWS] ${delay.inSeconds}초 후 재연결 시도 ($_reconnectAttempt/$_maxReconnectAttempt)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_disposed) _connect();
    });
  }
}
