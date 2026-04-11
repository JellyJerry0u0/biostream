class HomeQuestItem {
  HomeQuestItem({
    required this.id,
    required this.title,
    required this.detail,
    this.isDone = false,
    this.committedActionId,
    this.sectionKey,
  });

  final String id;
  final String title;
  final String detail;
  bool isDone;
  /// 서버 committed_action id (체크인 API용). null이면 리포트 추출 항목
  final int? committedActionId;
  /// 리포트 탭 키 (goals, sleep, uv …) — 분포 그래프용
  final String? sectionKey;
}

class HomeQuestLoadResult {
  const HomeQuestLoadResult({
    required this.success,
    this.errorMessage,
    this.lifestyleId,
    this.questItems = const [],
    this.originalImageUrl,
    this.generatedImageUrl,
    this.predictionPoint,
    this.summaryData,
  });

  final bool success;
  final String? errorMessage;
  final int? lifestyleId;
  final List<HomeQuestItem> questItems;
  final String? originalImageUrl;
  final String? generatedImageUrl;
  final String? predictionPoint;
  /// 리포트 `sections.summary.summary_data` (요약 탭과 동일 출처)
  final Map<String, dynamic>? summaryData;
}
