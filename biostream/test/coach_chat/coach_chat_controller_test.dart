import 'package:biostream/models/coach_models.dart';
import 'package:biostream/screens/coach_chat/coach_chat_controller.dart';
import 'package:biostream/services/coach_ws_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCoachWsClient extends CoachWsClient {
  int? connectedReportId;
  String? sentUserMessage;
  String? sentActionId;
  Map<String, dynamic>? sentActionPayload;
  String? sentModeEngine;

  @override
  Future<void> connect({String? sessionId, int? reportId}) async {
    connectedReportId = reportId;
  }

  @override
  void disconnect() {}

  @override
  void sendUserMessage(String message, {String mode = 'auto'}) {
    sentUserMessage = message;
  }

  @override
  void sendAction(String actionId, {Map<String, dynamic>? payload}) {
    sentActionId = actionId;
    sentActionPayload = payload;
  }

  @override
  void sendModeSwitch(String engine) {
    sentModeEngine = engine;
  }

  void emitConnected() => onConnected?.call();
  void emitDisconnected() => onDisconnected?.call();
  void emitStart(String id) => onStart?.call({'assistant_message_id': id});
  void emitDelta(String id, String delta) =>
      onDelta?.call({'assistant_message_id': id, 'delta': delta});
  void emitDone(String id) => onDone?.call({'assistant_message_id': id});
  void emitError(String id, String message) => onError?.call({
        'assistant_message_id': id,
        'message': message,
      });
  void emitToolStatusRunning() =>
      onToolStatus?.call({'tool': 'generate_today_plan', 'status': 'running'});
  void emitToolStatusDone() =>
      onToolStatus?.call({'tool': 'generate_today_plan', 'status': 'done'});
}

void main() {
  group('CoachChatController', () {
    test('queueUserMessage는 비어있거나 스트리밍 중이면 null을 반환한다', () {
      final controller = CoachChatController(wsClient: _FakeCoachWsClient());
      final streamingState =
          CoachChatUiState.initial().copyWith(isAssistantStreaming: true);

      final emptyResult = controller.queueUserMessage(
        CoachChatUiState.initial(),
        '   ',
      );
      final streamingResult = controller.queueUserMessage(streamingState, '안녕');

      expect(emptyResult, isNull);
      expect(streamingResult, isNull);
    });

    test('queueUserMessage는 사용자 메시지를 상태에 추가한다', () {
      final controller = CoachChatController(wsClient: _FakeCoachWsClient());

      final next = controller.queueUserMessage(
        CoachChatUiState.initial(),
        '커피가 피부에 미치는 영향은?',
      );

      expect(next, isNotNull);
      expect(next!.messages.length, 1);
      expect(next.messages.first.role, 'user');
      expect(next.messages.first.content, '커피가 피부에 미치는 영향은?');
    });

    test('bindWsCallbacks는 start/delta/done 이벤트를 상태에 반영한다', () {
      final fakeWs = _FakeCoachWsClient();
      final controller = CoachChatController(wsClient: fakeWs);
      var state = CoachChatUiState.initial();
      final scrollFlags = <bool>[];

      controller.bindWsCallbacks(
        getState: () => state,
        onStateChanged: (nextState, {scrollToBottom = false}) {
          state = nextState;
          scrollFlags.add(scrollToBottom);
        },
      );

      fakeWs.emitConnected();
      expect(state.isConnected, isTrue);

      fakeWs.emitStart('a1');
      expect(state.messages.length, 1);
      expect(state.messages.first.role, 'assistant');
      expect(state.isAssistantStreaming, isTrue);

      fakeWs.emitDelta('a1', 'Hello');
      expect(state.messages.first.content, 'Hello');

      fakeWs.emitDone('a1');
      expect(state.isAssistantStreaming, isFalse);
      expect(state.messages.first.isStreaming, isFalse);

      expect(scrollFlags.where((v) => v).length, greaterThanOrEqualTo(3));
    });

    test('tool status running/done 이벤트가 상태에 반영된다', () {
      final fakeWs = _FakeCoachWsClient();
      final controller = CoachChatController(wsClient: fakeWs);
      var state = CoachChatUiState.initial();

      controller.bindWsCallbacks(
        getState: () => state,
        onStateChanged: (nextState, {scrollToBottom = false}) {
          state = nextState;
        },
      );

      fakeWs.emitToolStatusRunning();
      expect(state.currentToolStatus, isNotNull);
      expect(state.currentToolStatus!.isRunning, isTrue);

      fakeWs.emitToolStatusDone();
      expect(state.currentToolStatus, isNull);
    });

    test('error 이벤트는 어시스턴트 메시지에 경고를 추가한다', () {
      final fakeWs = _FakeCoachWsClient();
      final controller = CoachChatController(wsClient: fakeWs);
      var state = CoachChatUiState.initial();

      controller.bindWsCallbacks(
        getState: () => state,
        onStateChanged: (nextState, {scrollToBottom = false}) {
          state = nextState;
        },
      );

      fakeWs.emitStart('a2');
      fakeWs.emitDelta('a2', '중간 응답');
      fakeWs.emitError('a2', '서버 오류');

      final msg = state.messages.first;
      expect(msg.content, contains('중간 응답'));
      expect(msg.content, contains('⚠️ 서버 오류'));
      expect(state.isAssistantStreaming, isFalse);
    });

    test('sendAction/sendModeSwitch/sendUserMessage가 ws에 전달된다', () {
      final fakeWs = _FakeCoachWsClient();
      final controller = CoachChatController(wsClient: fakeWs);
      final action = ActionItem(
        id: 'save_goal',
        label: '목표 저장',
        payload: {'goal': 'sleep'},
      );

      controller.connect(reportId: 11);
      controller.sendUserMessage('테스트');
      controller.sendAction(action);
      controller.sendModeSwitch(CoachEngine.deep);

      expect(fakeWs.connectedReportId, 11);
      expect(fakeWs.sentUserMessage, '테스트');
      expect(fakeWs.sentActionId, 'save_goal');
      expect(fakeWs.sentActionPayload, {'goal': 'sleep'});
      expect(fakeWs.sentModeEngine, 'deep');
    });
  });
}
