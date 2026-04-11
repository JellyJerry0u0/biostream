import 'package:flutter/foundation.dart';
import '../../models/coach_models.dart';
import '../../services/coach_goal_service.dart';
import '../../services/coach_ws_client.dart';
import '../../services/habit_service.dart';

class CoachChatUiState {
  const CoachChatUiState({
    required this.messages,
    required this.isConnected,
    required this.isAssistantStreaming,
    required this.engine,
    required this.currentToolStatus,
    this.coachProgress,
    this.pendingGoalProposals = const [],
    this.habitDomainChartData,
    this.pendingHabitPersonalizations = const [],
  });

  factory CoachChatUiState.initial() {
    return const CoachChatUiState(
      messages: [],
      isConnected: false,
      isAssistantStreaming: false,
      engine: CoachEngine.quick,
      currentToolStatus: null,
      coachProgress: null,
      pendingGoalProposals: [],
      habitDomainChartData: null,
      pendingHabitPersonalizations: [],
    );
  }

  final List<CoachChatMessage> messages;
  final bool isConnected;
  final bool isAssistantStreaming;
  final CoachEngine engine;
  final ToolStatusEvent? currentToolStatus;
  final CoachProgressEvent? coachProgress;
  final List<GoalProposalItem> pendingGoalProposals;
  final HabitDomainChartData? habitDomainChartData;
  final List<HabitPersonalizationItem> pendingHabitPersonalizations;

  CoachChatUiState copyWith({
    List<CoachChatMessage>? messages,
    bool? isConnected,
    bool? isAssistantStreaming,
    CoachEngine? engine,
    ToolStatusEvent? currentToolStatus,
    bool clearToolStatus = false,
    CoachProgressEvent? coachProgress,
    bool clearCoachProgress = false,
    List<GoalProposalItem>? pendingGoalProposals,
    bool clearGoalProposals = false,
    HabitDomainChartData? habitDomainChartData,
    bool clearHabitDomainChart = false,
    List<HabitPersonalizationItem>? pendingHabitPersonalizations,
    bool clearHabitPersonalizations = false,
  }) {
    return CoachChatUiState(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isAssistantStreaming: isAssistantStreaming ?? this.isAssistantStreaming,
      engine: engine ?? this.engine,
      currentToolStatus: clearToolStatus
          ? null
          : (currentToolStatus ?? this.currentToolStatus),
      coachProgress: clearCoachProgress
          ? null
          : (coachProgress ?? this.coachProgress),
      pendingGoalProposals: clearGoalProposals
          ? const []
          : (pendingGoalProposals ?? this.pendingGoalProposals),
      habitDomainChartData: clearHabitDomainChart
          ? null
          : (habitDomainChartData ?? this.habitDomainChartData),
      pendingHabitPersonalizations: clearHabitPersonalizations
          ? const []
          : (pendingHabitPersonalizations ?? this.pendingHabitPersonalizations),
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
    VoidCallback? onConnectedExtra,
    VoidCallback? onAssistantStreamStarting,
    void Function(String assistantMessageId)? onAssistantStreamDone,
  }) {
    _wsClient.onConnected = () {
      onStateChanged(getState().copyWith(isConnected: true));
      onConnectedExtra?.call();
    };

    _wsClient.onDisconnected = () {
      onStateChanged(getState().copyWith(isConnected: false));
    };

    _wsClient.onStart = (data) {
      onAssistantStreamStarting?.call();
      final current = getState();
      final msgId = data['assistant_message_id'] as String? ?? '';
      final ch = current.engine;
      final nextMessages = List<CoachChatMessage>.from(current.messages)
        ..add(CoachChatMessage(
          id: msgId,
          role: 'assistant',
          channel: ch,
          isStreaming: true,
        ));
      onStateChanged(
        current.copyWith(
          messages: nextMessages,
          isAssistantStreaming: true,
          clearCoachProgress: true,
          clearGoalProposals: true,
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
          engine == 'coach' ? CoachEngine.coach : CoachEngine.quick;
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

    _wsClient.onCoachProgress = (data) {
      final current = getState();
      final event = CoachProgressEvent.fromJson(data);
      onStateChanged(
        current.copyWith(
          coachProgress: event,
        ),
      );
    };

    _wsClient.onGoalProposals = (data) {
      final current = getState();
      final raw = data['items'] as List<dynamic>? ?? [];
      final items = raw
          .map((e) => GoalProposalItem.fromJson(e as Map<String, dynamic>))
          .toList();
      onStateChanged(
        current.copyWith(pendingGoalProposals: items),
      );
    };

    _wsClient.onHabitDomainChart = (data) {
      final current = getState();
      final chart = HabitDomainChartData.fromJson(data);
      onStateChanged(current.copyWith(habitDomainChartData: chart));
    };

    _wsClient.onHabitPersonalizationProposals = (data) {
      final current = getState();
      final raw = data['items'] as List<dynamic>? ?? [];
      final items = raw
          .map((e) => HabitPersonalizationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      onStateChanged(current.copyWith(pendingHabitPersonalizations: items));
    };

    _wsClient.onDone = (data) {
      final current = getState();
      final msgId = data['assistant_message_id'] as String? ?? '';
      final nextMessages = List<CoachChatMessage>.from(current.messages);
      final msg = _findMessage(nextMessages, msgId);
      if (msg != null) {
        msg.isStreaming = false;
      }
      onAssistantStreamDone?.call(msgId);
      onStateChanged(
        current.copyWith(
          messages: nextMessages,
          isAssistantStreaming: false,
          clearToolStatus: true,
          clearCoachProgress: true,
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
        channel: state.engine,
        content: text,
      ));

    return state.copyWith(messages: nextMessages);
  }

  CoachEngine toggleEngine(CoachEngine currentEngine) {
    return currentEngine == CoachEngine.quick
        ? CoachEngine.coach
        : CoachEngine.quick;
  }

  void sendUserMessage(String text, {CoachEngine? engine}) {
    final eng = engine ?? CoachEngine.quick;
    _wsClient.sendUserMessage(
      text,
      engine: eng == CoachEngine.coach ? 'coach' : null,
    );
  }

  /// 목표 동의 REST (`POST /api/coach/goals/consent`) — UI에서 호출
  Future<Map<String, dynamic>> submitGoalConsent({
    required String sessionId,
    required String goalId,
    required bool accept,
    String? revisedTarget,
  }) {
    return CoachGoalService().submitConsent(
      sessionId: sessionId,
      goalId: goalId,
      accept: accept,
      revisedTarget: revisedTarget,
    );
  }

  void sendAction(ActionItem action) {
    _wsClient.sendAction(action.id, payload: action.payload);
  }

  void sendModeSwitch(CoachEngine engine, {String? context}) {
    _wsClient.sendModeSwitch(engine.name, context: context);
  }

  /// 습관 개인화 수락 — 서버에 PATCH로 제목/설명 업데이트 후 목록에서 제거
  Future<void> acceptPersonalization({
    required HabitPersonalizationItem item,
    required CoachChatUiState Function() getState,
    required CoachChatStateListener onStateChanged,
  }) async {
    await HabitService().updateCommittedAction(
      committedActionId: item.actionId,
      actionTitle: item.personalizedTitle,
      actionDetail: item.personalizedDetail,
    );
    _removePersonalizationItem(item.actionId, getState, onStateChanged);
  }

  /// 습관 개인화 거절
  /// - 첫 거절: REST로 재생성 요청 → 새 제안으로 교체 (isRegenerated=true)
  /// - 두 번째 거절: 원본 유지하고 목록에서 제거
  Future<void> rejectPersonalization({
    required HabitPersonalizationItem item,
    required CoachChatUiState Function() getState,
    required CoachChatStateListener onStateChanged,
  }) async {
    if (item.isRegenerated) {
      // 2번째 거절 — 원본 그대로 유지 (서버 업데이트 없음)
      _removePersonalizationItem(item.actionId, getState, onStateChanged);
      return;
    }

    // 첫 거절 — 재생성 요청
    final result = await HabitService().personalizeCommittedAction(
      committedActionId: item.actionId,
    );

    final current = getState();
    final updated = List<HabitPersonalizationItem>.from(
        current.pendingHabitPersonalizations);
    final idx = updated.indexWhere((e) => e.actionId == item.actionId);
    if (idx == -1) return;

    if (result['success'] == true && result['proposal'] != null) {
      final proposal = result['proposal'] as Map<String, dynamic>;
      updated[idx] = item.copyWith(
        personalizedTitle: proposal['title'] as String? ?? item.personalizedTitle,
        personalizedDetail: proposal['detail'] as String? ?? item.personalizedDetail,
        reason: proposal['reason'] as String? ?? item.reason,
        isRegenerated: true,
      );
    } else {
      // 재생성 실패 시에도 isRegenerated=true 표시해 다음 거절 시 원본 유지
      updated[idx] = item.copyWith(isRegenerated: true);
    }

    final next = current.copyWith(pendingHabitPersonalizations: updated);
    onStateChanged(next);
  }

  void _removePersonalizationItem(
    int actionId,
    CoachChatUiState Function() getState,
    CoachChatStateListener onStateChanged,
  ) {
    final current = getState();
    final updated = current.pendingHabitPersonalizations
        .where((e) => e.actionId != actionId)
        .toList();
    onStateChanged(current.copyWith(pendingHabitPersonalizations: updated));

    if (updated.isEmpty) {
      _wsClient.sendActionPlanComplete();
    }
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
