import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../services/lifestyle_service.dart';
import 'result_screen_helper.dart';

class LoadLifestyleResult {
  final bool success;
  final Map<String, dynamic>? lifestyleData;
  final String? originalImageUrl;
  final String? generatedImageUrl;
  final String? errorMessage;

  const LoadLifestyleResult({
    required this.success,
    this.lifestyleData,
    this.originalImageUrl,
    this.generatedImageUrl,
    this.errorMessage,
  });
}

class GenerateReportResult {
  final bool success;
  final bool tokenExpired;
  final String? errorMessage;
  final Map<String, dynamic>? lifestyleData;
  final Map<String, dynamic>? reportData;
  final String? originalImageUrl;
  final String? generatedImageUrl;
  final String? selectedTab;

  const GenerateReportResult({
    required this.success,
    this.tokenExpired = false,
    this.errorMessage,
    this.lifestyleData,
    this.reportData,
    this.originalImageUrl,
    this.generatedImageUrl,
    this.selectedTab,
  });
}

class SaveComparisonResult {
  final bool success;
  final String message;

  const SaveComparisonResult({
    required this.success,
    required this.message,
  });
}

class ResultScreenController {
  final LifestyleService _lifestyleService;
  final String? _situationText;

  ResultScreenController({
    required LifestyleService lifestyleService,
    required String? situationText,
  })  : _lifestyleService = lifestyleService,
        _situationText = situationText;

  Future<LoadLifestyleResult> loadLifestyleData() async {
    try {
      final lifestyleResult = await _lifestyleService.getLifestyleData();
      debugPrint('🔍 Lifestyle 데이터 로드 결과: $lifestyleResult');

      if (lifestyleResult['success'] == true && lifestyleResult['data'] != null) {
        final lifestyleData = lifestyleResult['data'] as Map<String, dynamic>;
        final resolvedOriginal = await ResultScreenHelper.resolveImageUrl(
          ResultScreenHelper.extractOriginalImageUrl(lifestyleData, null),
        );
        final resolvedGenerated = await ResultScreenHelper.resolveImageUrl(
          ResultScreenHelper.extractGeneratedImageUrl(lifestyleData, null),
        );
        return LoadLifestyleResult(
          success: true,
          lifestyleData: lifestyleData,
          originalImageUrl: resolvedOriginal,
          generatedImageUrl: resolvedGenerated,
        );
      }

      return LoadLifestyleResult(
        success: false,
        errorMessage: lifestyleResult['message']?.toString() ?? '데이터를 불러올 수 없습니다.',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ 에러 발생: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return LoadLifestyleResult(
        success: false,
        errorMessage: '데이터 로드 중 오류가 발생했습니다: $e',
      );
    }
  }

  Future<GenerateReportResult> generateHealthReport({
    required Map<String, dynamic>? lifestyleData,
    required Map<String, dynamic>? currentLifestyleData,
    required Future<bool?> Function() showRegenerateDialog,
    bool force = false,
  }) async {
    try {
      final lifestyleId = lifestyleData?['lifestyle_id'] as int?;
      if (lifestyleId == null) {
        return const GenerateReportResult(
          success: false,
          errorMessage: '설문조사 데이터를 찾을 수 없습니다. 먼저 설문조사를 완료해주세요.',
        );
      }

      final result = await _lifestyleService.generateHealthReport(
        lifestyleId,
        force: force,
        situationText: _situationText,
      );

      if (result['success'] != true) {
        if (result['token_expired'] == true) {
          return const GenerateReportResult(
            success: false,
            tokenExpired: true,
          );
        }
        return GenerateReportResult(
          success: false,
          errorMessage: result['message']?.toString() ?? '건강 리포트를 생성할 수 없습니다.',
        );
      }

      if (result['already_exists'] == true && !force) {
        final shouldRegenerate = await showRegenerateDialog();
        if (shouldRegenerate == true) {
          return generateHealthReport(
            lifestyleData: lifestyleData,
            currentLifestyleData: currentLifestyleData,
            showRegenerateDialog: showRegenerateDialog,
            force: true,
          );
        }
      }

      final rawReport = result['report'];
      if (rawReport is! Map<String, dynamic>) {
        return GenerateReportResult(
          success: false,
          errorMessage: result['message']?.toString() ?? '건강 리포트를 생성할 수 없습니다.',
        );
      }

      final reportData = rawReport.containsKey('tabs') && rawReport.containsKey('sections')
          ? rawReport
          : ResultScreenHelper.convertOldSchemaToNew(rawReport, result['cards']);

      final refreshedLifestyleResult = await _lifestyleService.getLifestyleData();
      Map<String, dynamic>? refreshedLifestyleData;
      if (refreshedLifestyleResult['success'] == true &&
          refreshedLifestyleResult['data'] != null) {
        refreshedLifestyleData =
            refreshedLifestyleResult['data'] as Map<String, dynamic>;
      }

      final mergedLifestyleData = refreshedLifestyleData ?? currentLifestyleData;
      final resolvedOriginal = await ResultScreenHelper.resolveImageUrl(
        ResultScreenHelper.extractOriginalImageUrl(mergedLifestyleData, reportData),
      );
      final resolvedGenerated = await ResultScreenHelper.resolveImageUrl(
        ResultScreenHelper.extractGeneratedImageUrl(mergedLifestyleData, reportData),
      );

      final tabs = reportData['tabs'] as List<dynamic>? ?? [];
      final selectedTab = tabs.isNotEmpty ? tabs.first.toString() : null;

      return GenerateReportResult(
        success: true,
        lifestyleData: mergedLifestyleData,
        reportData: reportData,
        originalImageUrl: resolvedOriginal,
        generatedImageUrl: resolvedGenerated,
        selectedTab: selectedTab,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ 리포트 생성 에러: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return GenerateReportResult(
        success: false,
        errorMessage: '건강 리포트 생성 중 오류가 발생했습니다: $e',
      );
    }
  }

  Future<SaveComparisonResult> saveComparison({
    required int? lifestyleId,
    required Map<String, dynamic>? reportData,
    required String? generatedImageUrl,
  }) async {
    if (lifestyleId == null || reportData == null) {
      return const SaveComparisonResult(
        success: false,
        message: '저장할 리포트 데이터가 없습니다.',
      );
    }
    if (generatedImageUrl == null || generatedImageUrl.isEmpty) {
      return const SaveComparisonResult(
        success: false,
        message: '저장할 GPU 결과 이미지가 없습니다.',
      );
    }

    try {
      final saveReportResult = await _lifestyleService.saveGeneratedReport(
        lifestyleId: lifestyleId,
        report: reportData,
      );
      if (saveReportResult['success'] != true) {
        return SaveComparisonResult(
          success: false,
          message: saveReportResult['message']?.toString() ?? '리포트 저장에 실패했습니다.',
        );
      }

      final gpuBytes = await ResultScreenHelper.downloadImageBytes(generatedImageUrl);
      if (gpuBytes == null || gpuBytes.isEmpty) {
        return const SaveComparisonResult(
          success: false,
          message: '이미지 저장에 실패했습니다.',
        );
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final saveResult = await ImageGallerySaverPlus.saveImage(
        gpuBytes,
        quality: 100,
        name: 'biostream_gpu_result_$timestamp',
      );

      if (!ResultScreenHelper.isGallerySaveSuccess(saveResult)) {
        debugPrint('갤러리 저장 실패 응답: $saveResult');
        return const SaveComparisonResult(
          success: false,
          message: '갤러리 저장에 실패했습니다.',
        );
      }

      return const SaveComparisonResult(
        success: true,
        message: '리포트와 GPU 이미지가 저장되었습니다.',
      );
    } catch (e) {
      debugPrint('Save Comparison 실패: $e');
      return const SaveComparisonResult(
        success: false,
        message: '저장 중 오류가 발생했습니다.',
      );
    }
  }
}
