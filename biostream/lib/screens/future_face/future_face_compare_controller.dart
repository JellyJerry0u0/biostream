import '../../services/api_config.dart';
import '../../services/lifestyle_service.dart';

class FutureFaceLoadResult {
  const FutureFaceLoadResult({
    required this.futureImageUrl,
    required this.leftImageUrl,
    required this.simulationPromptText,
    required this.errorMessage,
  });

  /// 미래 얼굴 탭 슬라이더 왼쪽: 동일 /generate 입력 + **습관 점수 전부 100** skin-edit.
  /// 없으면(구 데이터) 촬영 원본으로 폴백.
  final String? leftImageUrl;
  /// 미래 얼굴 탭 슬라이더 오른쪽: 동일 입력 + **설문 생활습관** skin-edit(`generated_image_url`).
  final String? futureImageUrl;
  final String simulationPromptText;
  final String? errorMessage;
}

class FutureFaceCompareController {
  const FutureFaceCompareController(
      {required LifestyleService lifestyleService})
      : _lifestyleService = lifestyleService;

  final LifestyleService _lifestyleService;

  Future<FutureFaceLoadResult> loadLatestFutureFaceImages() async {
    final result = await _lifestyleService.getLatestFutureFace();

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>? ?? {};
      final generatedImage =
          await _resolveImageUrl(data['generated_image_url']?.toString());
      final idealHabitsImage =
          await _resolveImageUrl(data['ideal_habits_skin_image_url']?.toString());
      final originalImage =
          await _resolveImageUrl(data['original_image_url']?.toString());
      final leftImage = idealHabitsImage ?? originalImage;

      return FutureFaceLoadResult(
        futureImageUrl: generatedImage,
        leftImageUrl: leftImage,
        simulationPromptText:
            (data['simulation_prompt_text']?.toString().trim() ?? ''),
        errorMessage: null,
      );
    }

    return FutureFaceLoadResult(
      futureImageUrl: null,
      leftImageUrl: null,
      simulationPromptText: '',
      errorMessage: result['message']?.toString() ?? '이미지를 불러오지 못했습니다.',
    );
  }

  Future<String?> _resolveImageUrl(String? rawUrl) async {
    final value = rawUrl?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      try {
        final parsed = Uri.parse(value);
        final host = parsed.host.toLowerCase();
        if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
          final origin = await ApiConfig.getBaseOrigin();
          final originUri = Uri.parse(origin);
          final replaced = parsed.replace(
            scheme: originUri.scheme,
            host: originUri.host,
            port: originUri.hasPort ? originUri.port : null,
          );
          return replaced.toString();
        }
      } catch (_) {
        return value;
      }
      return value;
    }

    const marker = '/uploads/';
    final index = value.replaceAll('\\', '/').indexOf(marker);
    if (index >= 0) {
      final relativePath = value.replaceAll('\\', '/').substring(
            index + marker.length,
          );
      final origin = await ApiConfig.getBaseOrigin();
      return '$origin/data/image/$relativePath';
    }
    return value;
  }
}
