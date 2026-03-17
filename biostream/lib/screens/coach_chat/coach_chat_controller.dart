import '../../models/coach_models.dart';
import '../../services/coach_ws_client.dart';

class CoachChatUiState {
  const CoachChatUiState({
    required this.messages,
    required this.isConnected,
    required this.isAssistantStreaming,
    required this.engine,
    required this.currentToolStatus,
  });

  factory CoachChatUiState.initial() {
    return const CoachChatUiState(
      messages: [],
      isConnected: false,
      isAssistantStreaming: false,
      engine: CoachEngine.quick,
      currentToolStatus: null,
    );
  }

  final List<CoachChatMessage> messages;
  final bool isConnected;
  final bool isAssistantStreaming;
  final CoachEngine engine;
  final ToolStatusEvent? currentToolStatus;

  CoachChatUiState copyWith({
    List<CoachChatMessage>? messages,
    bool? isConnected,
    bool? isAssistantStreaming,
    CoachEngine? engine,
    ToolStatusEvent? currentToolStatus,
    bool clearToolStatus = false,
  }) {
    return CoachChatUiState(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isAssistantStreaming: isAssistantStreaming ?? this.isAssistantStreaming,
      engine: engine ?? this.engine,
      currentToolStatus: clearToolStatus
          ? null
          : (currentToolStatus ?? this.currentToolStatus),
    );
  }
}

typedef CoachChatStateListener = void Function(
  CoachChatUiState nextState, {
  bool scrollToBottom,
});

class CoachChatController {
  CoachChatController({required CoachWsClient wsClient}) : _wsClient = wsClient;

  final CoachWsClient _wsClient;

  void connect({int? reportId}) {
    _wsClient.connect(reportId: reportId);
  }

  void disconnect() {
    _wsClient.disconnect();
  }

  void bindWsCallbacks({
    required CoachChatUiState Function() getState,
    required CoachChatStateListener onStateChanged,
  }) {
    _wsClient.onConnected = () {
      onStateChanged(getState().copyWith(isConnected: true));
    };

    _wsClient.onDisconnected = () {
      onStateChanged(getState().copyWith(isConnected: false));
    };

    _wsClient.onStart = (data) {
      final current = getState();
      final msgId = data['assistant_message_id'] as String? ?? '';
      final nextMessages = List<CoachChatMessage>.from(current.messages)
        ..add(CoachChatMessage(
          id: msgId,
          role: 'assistant',
          isStreaming: true,
        ));
      onStateChanged(
        current.copyWith(
          messages: nextMessages,
          isAssistantStreaming: true,
        ),
        scrollToBottom: true,
      );
    };

    _wsClient.onDelta = (data) {
      final current = getState();
      final msgId = data['assistant_message_id'] as String? ?? '';
      final delta = data['delta'] as String? ?? '';
      final nextMessages = List<CoachChatMessage>.from(current.messages);
      final msg = _findMessage(nextMessages, msgId);
      msg?.appendDelta(delta);
      onStateChanged(
        current.copyWith(messages: nextMessages),
        scrollToBottom: true,
      );
    };

    _wsClient.onActions = (data) {
      final current = getState();
      final msgId = data['assistant_message_id'] as String? ?? '';
      final items = (data['items'] as List<dynamic>?)
              ?.map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final nextMessages = List<CoachChatMessage>.from(current.messages);
      final msg = _findMessage(nextMessages, msgId);
      if (msg != null) {
        msg.actions = items;
      }
      onStateChanged(current.copyWith(messages: nextMessages));
    };

    _wsClient.onCitations = (data) {
      final current = getState();
      final msgId = data['assistant_message_id'] as String? ?? '';
      final items = (data['items'] as List<dynamic>?)
              ?.map((e) => CitationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final nextMessages = List<CoachChatMessage>.from(current.messages);
      final msg = _findMessage(nextMessages, msgId);
      if (msg != null) {
        msg.citations = items;
      }
      onStateChanged(current.copyWith(messages: nextMessages));
    };

    _wsClient.onMemoryUpdate = (data) {};

    _wsClient.onModeInfo = (data) {
      final current = getState();
      final engine = data['engine'] as String?;
      if (engine == null) {
        return;
      }
      final nextEngine =
          engine == 'deep' ? CoachEngine.deep : CoachEngine.quick;
      onStateChanged(current.copyWith(engine: nextEngine));
    };

    _wsClient.onToolStatus = (data) {
      final current = getState();
      final event = ToolStatusEvent.fromJson(data);
      onStateChanged(
        current.copyWith(
          currentToolStatus: event.isRunning ? event : null,
          clearToolStatus: !event.isRunning,
        ),
      );
    };

    _wsClient.onDone = (data) {
      final current = getState();
      final msgId = data['assistant_message_id'] as String? ?? '';
      final nextMessages = List<CoachChatMessage>.from(current.messages);
      final msg = _findMessage(nextMessages, msgId);
      if (msg != null) {
        msg.isStreaming = false;
      }
      onStateChanged(
        current.copyWith(
          messages: nextMessages,
          isAssistantStreaming: false,
          clearToolStatus: true,
        ),
        scrollToBottom: true,
      );
    };

    _wsClient.onError = (data) {
      final current = getState();
      final nextMessages = List<CoachChatMessage>.from(current.messages);
      final errorMsg = data['message'] as String? ?? '오류가 발생했습니다.';
      final msgId = data['assistant_message_id'] as String?;
      if (msgId != null) {
        final msg = _findMessage(nextMessages, msgId);
        if (msg != null) {
          msg.content += '\n\n⚠️ $errorMsg';
          msg.isStreaming = false;
        }
      }
      onStateChanged(
        current.copyWith(
          messages: nextMessages,
          isAssistantStreaming: false,
        ),
      );
    };
  }

  CoachChatUiState? queueUserMessage(CoachChatUiState state, String rawText) {
    final text = rawText.trim();
    if (text.isEmpty || state.isAssistantStreaming) {
      return null;
    }

    final nextMessages = List<CoachChatMessage>.from(state.messages)
      ..add(CoachChatMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        content: text,
      ));

    return state.copyWith(messages: nextMessages);
  }

  CoachEngine toggleEngine(CoachEngine currentEngine) {
    return currentEngine == CoachEngine.quick
        ? CoachEngine.deep
        : CoachEngine.quick;
  }

  void sendUserMessage(String text) {
    _wsClient.sendUserMessage(text);
  }

  void sendAction(ActionItem action) {
    _wsClient.sendAction(action.id, payload: action.payload);
  }

  void sendModeSwitch(CoachEngine engine) {
    _wsClient.sendModeSwitch(engine.name);
  }

  CoachChatMessage? _findMessage(List<CoachChatMessage> messages, String id) {
    for (final message in messages) {
      if (message.id == id) {
        return message;
      }
    }
    return null;
  }
}
