/// 코치 챗봇 데이터 모델
/// 서버 ↔ 클라이언트 WebSocket 메시지 타입 매핑

// ══════════════════════════════════════════════
//  엔진 모드
// ══════════════════════════════════════════════

/// 코치 엔진: Quick(함수 체이닝) vs Deep(LangGraph + tool calling)
enum CoachEngine {
  quick,
  deep;

  String get label => this == quick ? '일반 코치' : '심화 코치';
  String get icon => this == quick ? 'bolt' : 'psychology';
}

// ══════════════════════════════════════════════
//  도구 실행 상태 이벤트
// ══════════════════════════════════════════════

/// Deep 모드에서 도구 실행 상태
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

// ══════════════════════════════════════════════
//  서버 → 클라이언트 메시지
// ══════════════════════════════════════════════

/// 채팅 메시지 (UI 렌더링 단위)
class CoachChatMessage {
  final String id;
  final String role; // "user" | "assistant"
  String content;
  final DateTime timestamp;
  List<ActionItem> actions;
  List<CitationItem> citations;
  bool isStreaming; // delta 수신 중 여부

  CoachChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    DateTime? timestamp,
    List<ActionItem>? actions,
    List<CitationItem>? citations,
    this.isStreaming = false,
  })  : timestamp = timestamp ?? DateTime.now(),
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
