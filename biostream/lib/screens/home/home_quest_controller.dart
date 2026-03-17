import 'package:shared_preferences/shared_preferences.dart';

import '../../services/lifestyle_service.dart';
import 'home_models.dart';

class HomeQuestController {
  HomeQuestController({required LifestyleService lifestyleService})
      : _lifestyleService = lifestyleService;

  final LifestyleService _lifestyleService;

  Future<HomeQuestLoadResult> loadQuestFromReport() async {
    final lifestyleResult = await _lifestyleService.getLifestyleData();

    if (lifestyleResult['success'] != true) {
      return const HomeQuestLoadResult(
        success: false,
        errorMessage: '생활습관 데이터를 불러오지 못했습니다.',
      );
    }

    final lifestyleData = lifestyleResult['data'];
    final images = lifestyleData is Map<String, dynamic>
        ? lifestyleData['images'] as Map<String, dynamic>?
        : null;

    final originalImageUrl = images?['original_image_url']?.toString();
    String? generatedImageUrl = images?['generated_image_url']?.toString();

    final lifestyleId = _toInt(
      lifestyleData is Map<String, dynamic>
          ? lifestyleData['lifestyle_id']
          : null,
    );

    if (lifestyleId == null) {
      return HomeQuestLoadResult(
        success: false,
        errorMessage: '분석 리포트가 아직 없습니다.',
        originalImageUrl: originalImageUrl,
        generatedImageUrl: generatedImageUrl,
      );
    }

    final reportResult = await _lifestyleService.getHealthReport(lifestyleId);
    if (reportResult['success'] != true) {
      return HomeQuestLoadResult(
        success: false,
        errorMessage: '리포트를 불러오지 못했습니다.',
        lifestyleId: lifestyleId,
        originalImageUrl: originalImageUrl,
        generatedImageUrl: generatedImageUrl,
      );
    }

    final report = reportResult['report'];
    final predictionPoint = _extractPredictionPoint(report);

    final reportGeneratedImage = _extractGeneratedImageFromReport(report);
    if ((generatedImageUrl == null || generatedImageUrl.isEmpty) &&
        reportGeneratedImage.isNotEmpty) {
      generatedImageUrl = reportGeneratedImage;
    }

    final extractedItems = _extractSolutionItems(report);
    final completedIdsFromServer = _extractCompletedIdsFromServer(report);

    if (extractedItems.isEmpty) {
      return HomeQuestLoadResult(
        success: false,
        errorMessage: '맞춤 솔루션이 아직 생성되지 않았습니다.',
        lifestyleId: lifestyleId,
        originalImageUrl: originalImageUrl,
        generatedImageUrl: generatedImageUrl,
        predictionPoint: predictionPoint,
      );
    }

    if (completedIdsFromServer.isNotEmpty) {
      for (final item in extractedItems) {
        item.isDone = completedIdsFromServer.contains(item.id);
      }
      await savePracticedStateToLocal(lifestyleId, extractedItems);
    } else {
      await restorePracticedStateFromLocal(lifestyleId, extractedItems);
    }

    return HomeQuestLoadResult(
      success: true,
      lifestyleId: lifestyleId,
      questItems: extractedItems,
      originalImageUrl: originalImageUrl,
      generatedImageUrl: generatedImageUrl,
      predictionPoint: predictionPoint,
    );
  }

  Future<void> restorePracticedStateFromLocal(
    int lifestyleId,
    List<HomeQuestItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final doneIds = prefs.getStringList(_questStorageKey(lifestyleId)) ?? [];
    for (final item in items) {
      item.isDone = doneIds.contains(item.id);
    }
  }

  Future<void> savePracticedStateToLocal(
    int lifestyleId,
    List<HomeQuestItem> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final doneIds =
        items.where((item) => item.isDone).map((item) => item.id).toList();
    await prefs.setStringList(_questStorageKey(lifestyleId), doneIds);
  }

  Future<Map<String, dynamic>> savePracticedStateToServer(
    int lifestyleId,
    List<HomeQuestItem> items,
  ) {
    final doneIds =
        items.where((item) => item.isDone).map((item) => item.id).toList();
    return _lifestyleService.updateQuestProgress(lifestyleId, doneIds);
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  List<HomeQuestItem> _extractSolutionItems(dynamic report) {
    final items = <HomeQuestItem>[];
    final seenTitles = <String>{};

    void addItem(String title, String detail) {
      final normalizedTitle = _cleanText(title);
      final normalizedDetail = _cleanText(detail);

      if (normalizedTitle.isEmpty) return;
      if (seenTitles.contains(normalizedTitle)) return;

      seenTitles.add(normalizedTitle);
      items.add(
        HomeQuestItem(
          id: normalizedTitle,
          title: normalizedTitle,
          detail: normalizedDetail,
        ),
      );
    }

    void collectCards(dynamic cards) {
      if (cards is! List) return;
      for (final card in cards) {
        if (card is! Map<String, dynamic>) continue;
        if (card['type'] != 'action') continue;

        final cardItems = card['items'];
        if (cardItems is! List) continue;

        for (final entry in cardItems) {
          if (entry is! Map<String, dynamic>) continue;
          final title = (entry['title'] ?? '').toString();
          final detail = (entry['detail'] ?? '').toString();
          addItem(title, detail);
        }
      }
    }

    void collectSection(dynamic section) {
      if (section is! Map<String, dynamic>) return;
      collectCards(section['cards']);

      final subsections = section['subsections'];
      if (subsections is List) {
        for (final subsection in subsections) {
          collectSection(subsection);
        }
      }
    }

    if (report is Map<String, dynamic>) {
      final sections = report['sections'];
      if (sections is Map<String, dynamic>) {
        for (final section in sections.values) {
          collectSection(section);
        }
      }

      collectCards(report['cards']);

      final actionItems = report['action_items'];
      if (actionItems is List) {
        for (final entry in actionItems) {
          if (entry is! Map<String, dynamic>) continue;
          addItem((entry['title'] ?? '').toString(),
              (entry['detail'] ?? '').toString());
        }
      }
    }

    return items.take(3).toList();
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'PMC\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'PMID\s*:?\s*\d+', caseSensitive: false), '')
        .trim();
  }

  String _extractGeneratedImageFromReport(dynamic report) {
    if (report is! Map<String, dynamic>) return '';
    final generatedImage = report['generated_image_url']?.toString() ?? '';
    return generatedImage.trim();
  }

  String _extractPredictionPoint(dynamic report) {
    if (report is! Map<String, dynamic>) return '';

    String extractFromCards(List<dynamic>? cards) {
      if (cards == null) return '';
      for (final card in cards) {
        if (card is! Map<String, dynamic>) continue;
        if (card['type'] != 'simulation') continue;
        final rawText = (card['text'] ?? '').toString().trim();
        if (rawText.isNotEmpty) {
          final firstSentence = rawText.split(RegExp(r'[.!?\n]')).first.trim();
          return firstSentence;
        }
      }
      return '';
    }

    final sections = report['sections'];
    if (sections is Map<String, dynamic>) {
      for (final section in sections.values) {
        if (section is! Map<String, dynamic>) continue;
        final direct = extractFromCards(section['cards'] as List<dynamic>?);
        if (direct.isNotEmpty) return direct;

        final subsections = section['subsections'];
        if (subsections is List) {
          for (final subsection in subsections) {
            if (subsection is! Map<String, dynamic>) continue;
            final fromSub =
                extractFromCards(subsection['cards'] as List<dynamic>?);
            if (fromSub.isNotEmpty) return fromSub;
          }
        }
      }
    }

    final cards = report['cards'];
    if (cards is List<dynamic>) {
      final fromRoot = extractFromCards(cards);
      if (fromRoot.isNotEmpty) return fromRoot;
    }

    return '';
  }

  Set<String> _extractCompletedIdsFromServer(dynamic report) {
    if (report is! Map<String, dynamic>) {
      return <String>{};
    }

    final questProgress = report['quest_progress'];
    if (questProgress is! Map<String, dynamic>) {
      return <String>{};
    }

    final completed = questProgress['completed_action_ids'];
    if (completed is! List) {
      return <String>{};
    }

    return completed
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  String _questStorageKey(int lifestyleId) => 'home_quest_done_$lifestyleId';
}
