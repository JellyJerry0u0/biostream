/// 코치 챗봇 데이터 모델
/// 서버 ↔ 클라이언트 WebSocket 메시지 타입 매핑
library;

// ══════════════════════════════════════════════
//  엔진 모드
// ══════════════════════════════════════════════

/// 코치 엔진: Quick vs Coach(LangGraph 적응형 코치)
enum CoachEngine {
  quick,
  coach;

  String get label => this == quick ? '일반 코치' : '코치 모드';
  String get icon => this == quick ? 'bolt' : 'psychology';
}

// ══════════════════════════════════════════════
//  도구 실행 상태 이벤트
// ══════════════════════════════════════════════

/// 도구 실행 상태 (레거시/특정 모드)
class ToolStatusEvent {
  final String? assistantMessageId;
  final String tool;
  final String status; // "running" | "done" | "error"

  ToolStatusEvent({
    this.assistantMessageId,
    required this.tool,
    required this.status,
  });

  factory ToolStatusEvent.fromJson(Map<String, dynamic> json) {
    return ToolStatusEvent(
      assistantMessageId: json['assistant_message_id'],
      tool: json['tool'] ?? '',
      status: json['status'] ?? '',
    );
  }

  /// 사용자에게 보여줄 상태 텍스트
  String get displayText {
    final toolLabels = {
      'search_evidence': '근거 검색',
      'save_goal': '목표 저장',
      'generate_today_plan': '플랜 생성',
      'fetch_report_summary': '리포트 조회',
    };
    final toolLabel = toolLabels[tool] ?? tool;
    switch (status) {
      case 'running':
        return '$toolLabel 중...';
      case 'done':
        return '$toolLabel 완료';
      case 'error':
        return '$toolLabel 실패';
      default:
        return toolLabel;
    }
  }

  bool get isRunning => status == 'running';
}

/// 코치 모드 LangGraph 진행 단계 (서버 `coach_progress`)
class CoachProgressEvent {
  final String? assistantMessageId;
  final String step;
  final String label;
  final String status;

  CoachProgressEvent({
    this.assistantMessageId,
    required this.step,
    required this.label,
    this.status = 'running',
  });

  factory CoachProgressEvent.fromJson(Map<String, dynamic> json) {
    return CoachProgressEvent(
      assistantMessageId: json['assistant_message_id'] as String?,
      step: json['step'] as String? ?? '',
      label: json['label'] as String? ?? '',
      status: json['status'] as String? ?? 'running',
    );
  }

  String get displayText => label;
}

/// 생활습관 개인화 제안 (`habit_personalization_proposals`)
class HabitPersonalizationItem {
  final int actionId;
  final String originalTitle;
  final String personalizedTitle;
  final String personalizedDetail;
  final String reason;
  /// true이면 이미 1회 재생성된 상태 (2번 거절 시 원본 유지)
  final bool isRegenerated;

  HabitPersonalizationItem({
    required this.actionId,
    required this.originalTitle,
    required this.personalizedTitle,
    required this.personalizedDetail,
    required this.reason,
    this.isRegenerated = false,
  });

  factory HabitPersonalizationItem.fromJson(Map<String, dynamic> json) {
    return HabitPersonalizationItem(
      actionId: (json['action_id'] as num?)?.toInt() ?? 0,
      originalTitle: json['original_title'] as String? ?? '',
      personalizedTitle: json['personalized_title'] as String? ?? '',
      personalizedDetail: json['personalized_detail'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  HabitPersonalizationItem copyWith({
    String? personalizedTitle,
    String? personalizedDetail,
    String? reason,
    bool? isRegenerated,
  }) {
    return HabitPersonalizationItem(
      actionId: actionId,
      originalTitle: originalTitle,
      personalizedTitle: personalizedTitle ?? this.personalizedTitle,
      personalizedDetail: personalizedDetail ?? this.personalizedDetail,
      reason: reason ?? this.reason,
      isRegenerated: isRegenerated ?? this.isRegenerated,
    );
  }
}

/// 도메인 분포 차트 데이터 (`habit_domain_chart`)
class HabitDomainChartData {
  final Map<String, int> before;
  final Map<String, int> after;

  const HabitDomainChartData({required this.before, required this.after});

  factory HabitDomainChartData.fromJson(Map<String, dynamic> json) {
    Map<String, int> _toIntMap(dynamic raw) {
      if (raw is Map) {
        return Map.fromEntries(
          raw.entries.map((e) => MapEntry(e.key.toString(), (e.value as num?)?.toInt() ?? 0)),
        );
      }
      return {};
    }

    return HabitDomainChartData(
      before: _toIntMap(json['before']),
      after: _toIntMap(json['after']),
    );
  }
}

/// 목표 조정 제안 (`goal_proposals`)
class GoalProposalItem {
  final String goalId;
  final String proposedTarget;
  final String reason;
  final bool pendingUserApproval;

  GoalProposalItem({
    required this.goalId,
    required this.proposedTarget,
    this.reason = '',
    this.pendingUserApproval = true,
  });

  factory GoalProposalItem.fromJson(Map<String, dynamic> json) {
    return GoalProposalItem(
      goalId: json['goal_id'] as String? ?? '',
      proposedTarget: json['proposed_target'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      pendingUserApproval: json['pending_user_approval'] as bool? ?? true,
    );
  }
}

// ══════════════════════════════════════════════
//  서버 → 클라이언트 메시지
// ══════════════════════════════════════════════

/// 채팅 메시지 (UI 렌더링 단위)
class CoachChatMessage {
  final String id;
  final String role; // "user" | "assistant"
  String content;
  /// 퀵/코치 스레드. null이면 quick(핫 리로드·구 인스턴스 호환).
  final CoachEngine? _channel;
  final DateTime timestamp;
  List<ActionItem> actions;
  List<CitationItem> citations;
  bool isStreaming; // delta 수신 중 여부

  CoachEngine get channel => _channel ?? CoachEngine.quick;

  CoachChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    CoachEngine? channel,
    DateTime? timestamp,
    List<ActionItem>? actions,
    List<CitationItem>? citations,
    this.isStreaming = false,
  })  : _channel = channel,
        timestamp = timestamp ?? DateTime.now(),
        actions = actions ?? [],
        citations = citations ?? [];

  /// delta 텍스트 append
  void appendDelta(String delta) {
    content += delta;
  }
}

/// 액션 버튼 아이템
class ActionItem {
  final String id;
  final String label;
  final Map<String, dynamic>? payload;

  ActionItem({required this.id, required this.label, this.payload});

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        if (payload != null) 'payload': payload,
      };
}

/// 인용(Citation) 아이템
class CitationItem {
  final String? paperId;
  final String? chunkId;
  final String? sourceSection;
  final double? score;

  CitationItem({this.paperId, this.chunkId, this.sourceSection, this.score});

  factory CitationItem.fromJson(Map<String, dynamic> json) {
    return CitationItem(
      paperId: json['paper_id'],
      chunkId: json['chunk_id'],
      sourceSection: json['source_section'],
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

/// 메모리 업데이트 아이템
class MemoryItem {
  final String key;
  final String value;

  MemoryItem({required this.key, required this.value});

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      key: json['key'] ?? '',
      value: json['value'] ?? '',
    );
  }
}

// ══════════════════════════════════════════════
//  클라이언트 → 서버 메시지 빌더
// ══════════════════════════════════════════════

/// 사용자 메시지 빌더
Map<String, dynamic> buildUserMessage({
  required String message,
  String? sessionId,
  int? reportId,
  String mode = 'auto',
  CoachEngine? engine,
}) {
  return {
    'type': 'user_message',
    if (sessionId != null) 'session_id': sessionId,
    'message': message,
    if (reportId != null) 'report_id': reportId,
    'mode': mode,
    if (engine != null) 'engine': engine.name,
  };
}

/// 액션 이벤트 빌더
Map<String, dynamic> buildActionEvent({
  required String actionId,
  String? sessionId,
  Map<String, dynamic>? payload,
}) {
  return {
    'type': 'action',
    if (sessionId != null) 'session_id': sessionId,
    'action_id': actionId,
    if (payload != null) 'payload': payload,
  };
}

/// 모드 전환 요청 빌더
Map<String, dynamic> buildModeSwitch({
  required CoachEngine engine,
}) {
  return {
    'type': 'mode_switch',
    'engine': engine.name,
  };
}
