class HomeQuestItem {
  HomeQuestItem({
    required this.id,
    required this.title,
    required this.detail,
    this.isDone = false,
  });

  final String id;
  final String title;
  final String detail;
  bool isDone;
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
  });

  final bool success;
  final String? errorMessage;
  final int? lifestyleId;
  final List<HomeQuestItem> questItems;
  final String? originalImageUrl;
  final String? generatedImageUrl;
  final String? predictionPoint;
}
