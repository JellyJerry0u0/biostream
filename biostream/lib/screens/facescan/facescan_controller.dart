import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/image_service.dart';

class FaceScanUploadResult {
  const FaceScanUploadResult({
    required this.success,
    this.message,
    this.originalImageUrl,
    this.lifestyleId,
  });

  final bool success;
  final String? message;
  final String? originalImageUrl;
  final int? lifestyleId;
}

class FaceScanController {
  FaceScanController({required ImageService imageService})
      : _imageService = imageService;

  final ImageService _imageService;

  Future<FaceScanUploadResult> uploadForSurvey(XFile image) async {
    final result = await _imageService.uploadImage(image);
    if (result['success'] != true) {
      return FaceScanUploadResult(
        success: false,
        message: (result['message'] ?? '이미지 업로드에 실패했습니다.').toString(),
      );
    }

    final originalImageUrl = result['original_image_url'] as String?;
    final savedPath = result['saved_path'] as String?;
    final finalImageUrl = originalImageUrl ?? savedPath;

    return FaceScanUploadResult(
      success: true,
      originalImageUrl: finalImageUrl,
      lifestyleId:
          result['lifestyle_id'] is int ? result['lifestyle_id'] as int : null,
      message: (result['message'] ?? '').toString(),
    );
  }

  Future<void> requestDefaultGenerate(int lifestyleId) async {
    final result = await _imageService.requestGenerateDefault(lifestyleId);
    if (result['success'] == true) {
      debugPrint(
        '[FaceScanController] /generate 기본 요청 성공: lifestyle_id=$lifestyleId',
      );
      return;
    }
    debugPrint(
      '[FaceScanController] /generate 기본 요청 실패: ${result['message'] ?? '알 수 없는 오류'}',
    );
  }
}
