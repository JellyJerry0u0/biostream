import '../../services/api_config.dart';
import '../../services/lifestyle_service.dart';

class FutureFaceLoadResult {
  const FutureFaceLoadResult({
    required this.futureImageUrl,
    required this.currentImageUrl,
    required this.simulationPromptText,
    required this.errorMessage,
  });

  final String? futureImageUrl;
  final String? currentImageUrl;
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
      final originalImage =
          await _resolveImageUrl(data['original_image_url']?.toString());

      return FutureFaceLoadResult(
        futureImageUrl: generatedImage,
        currentImageUrl: originalImage,
        simulationPromptText:
            (data['simulation_prompt_text']?.toString().trim() ?? ''),
        errorMessage: null,
      );
    }

    return FutureFaceLoadResult(
      futureImageUrl: null,
      currentImageUrl: null,
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
