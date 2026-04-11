import 'package:shared_preferences/shared_preferences.dart';

import '../../services/lifestyle_service.dart';
import '../../services/habit_service.dart';
import 'home_models.dart';

class HomeQuestController {
  HomeQuestController({
    required LifestyleService lifestyleService,
    HabitService? habitService,
  })  : _lifestyleService = lifestyleService,
        _habitService = habitService ?? HabitService();

  final LifestyleService _lifestyleService;
  final HabitService _habitService;

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
    final summaryData = _extractSummaryData(report);

    final reportGeneratedImage = _extractGeneratedImageFromReport(report);
    if ((generatedImageUrl == null || generatedImageUrl.isEmpty) &&
        reportGeneratedImage.isNotEmpty) {
      generatedImageUrl = reportGeneratedImage;
    }

    // 1) 사용자가 저장한 생활습관 전체 (특정 lifestyle에 한정하지 않음)
    final habitResult = await _habitService.getCommittedActions();
    if (habitResult['success'] == true) {
      final actions = habitResult['committed_actions'] as List<dynamic>? ?? [];
      if (actions.isNotEmpty) {
        final items = <HomeQuestItem>[];
        for (final a in actions) {
          if (a is! Map<String, dynamic>) continue;
          final aid = a['id'] as int?;
          final title = (a['action_title'] ?? '').toString();
          final detail = (a['action_detail'] ?? '').toString();
          if (title.isEmpty) continue;
          final todayCompleted = a['today_completed'];
          items.add(HomeQuestItem(
            id: 'committed_$aid',
            title: title,
            detail: detail,
            isDone: todayCompleted == true,
            committedActionId: aid,
            sectionKey: a['section_key']?.toString(),
          ));
        }
        return HomeQuestLoadResult(
          success: true,
          lifestyleId: lifestyleId,
          questItems: items,
          originalImageUrl: originalImageUrl,
          generatedImageUrl: generatedImageUrl,
          predictionPoint: predictionPoint,
          summaryData: summaryData,
        );
      }
    }

    // 2) 추가한 습관이 없으면 리포트에서 추출 (추천)
    final extractedItems = _extractSolutionItems(report);
    final completedIdsFromServer = _extractCompletedIdsFromServer(report);

    if (extractedItems.isEmpty) {
      return HomeQuestLoadResult(
        success: false,
        errorMessage: '리포트에서 행동을 탭해 생활습관에 담아 보세요.',
        lifestyleId: lifestyleId,
        originalImageUrl: originalImageUrl,
        generatedImageUrl: generatedImageUrl,
        predictionPoint: predictionPoint,
        summaryData: summaryData,
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
      summaryData: summaryData,
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

  Future<Map<String, dynamic>> retireCommittedAction(int committedActionId) async {
    return _habitService.retireCommittedAction(committedActionId: committedActionId);
  }

  Future<Map<String, dynamic>> savePracticedStateToServer(
    int lifestyleId,
    List<HomeQuestItem> items, {
    HomeQuestItem? toggledItem,
  }) async {
    if (toggledItem?.committedActionId != null) {
      final today = DateTime.now().toIso8601String().split('T').first;
      return _habitService.checkIn(
        committedActionId: toggledItem!.committedActionId!,
        checkDate: today,
        completed: toggledItem.isDone,
      );
    }
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

    void addItem(String title, String detail, String? sectionKey) {
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
          sectionKey: sectionKey,
        ),
      );
    }

    void collectCards(dynamic cards, String sectionKey) {
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
          addItem(title, detail, sectionKey);
        }
      }
    }

    void collectSection(dynamic section, String sectionKey) {
      if (section is! Map<String, dynamic>) return;
      collectCards(section['cards'], sectionKey);

      final subsections = section['subsections'];
      if (subsections is List) {
        for (final subsection in subsections) {
          collectSection(subsection, sectionKey);
        }
      }
    }

    if (report is Map<String, dynamic>) {
      final sections = report['sections'];
      if (sections is Map<String, dynamic>) {
        for (final e in sections.entries) {
          collectSection(e.value, e.key);
        }
      }

      collectCards(report['cards'], 'other');

      final actionItems = report['action_items'];
      if (actionItems is List) {
        for (final entry in actionItems) {
          if (entry is! Map<String, dynamic>) continue;
          addItem((entry['title'] ?? '').toString(),
              (entry['detail'] ?? '').toString(), 'other');
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

  Map<String, dynamic>? _extractSummaryData(dynamic report) {
    if (report is! Map<String, dynamic>) return null;
    final sections = report['sections'];
    if (sections is! Map<String, dynamic>) return null;
    final summary = sections['summary'];
    if (summary is! Map<String, dynamic>) return null;
    final raw = summary['summary_data'];
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
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
