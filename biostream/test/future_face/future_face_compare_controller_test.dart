import 'package:biostream/screens/future_face/future_face_compare_controller.dart';
import 'package:biostream/services/lifestyle_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLifestyleService extends LifestyleService {
  _FakeLifestyleService(this._result);

  final Map<String, dynamic> _result;

  @override
  Future<Map<String, dynamic>> getLatestFutureFace() async => _result;
}

void main() {
  group('FutureFaceCompareController', () {
    test('maps successful response into load result', () async {
      final service = _FakeLifestyleService({
        'success': true,
        'data': {
          'generated_image_url': 'https://cdn.example.com/future.jpg',
          'ideal_habits_skin_image_url': 'https://cdn.example.com/ideal.jpg',
          'original_image_url': 'https://cdn.example.com/current.jpg',
          'simulation_prompt_text': '  sample prompt  ',
        },
      });
      final controller = FutureFaceCompareController(lifestyleService: service);

      final result = await controller.loadLatestFutureFaceImages();

      expect(result.futureImageUrl, 'https://cdn.example.com/future.jpg');
      expect(result.leftImageUrl, 'https://cdn.example.com/ideal.jpg');
      expect(result.simulationPromptText, 'sample prompt');
      expect(result.errorMessage, isNull);
    });

    test('left image falls back to original when ideal habits url absent', () async {
      final service = _FakeLifestyleService({
        'success': true,
        'data': {
          'generated_image_url': 'https://cdn.example.com/future.jpg',
          'original_image_url': 'https://cdn.example.com/current.jpg',
          'simulation_prompt_text': '',
        },
      });
      final controller = FutureFaceCompareController(lifestyleService: service);

      final result = await controller.loadLatestFutureFaceImages();

      expect(result.leftImageUrl, 'https://cdn.example.com/current.jpg');
    });

    test('maps failed response with fallback message', () async {
      final service = _FakeLifestyleService({
        'success': false,
        'message': 'fetch failed',
      });
      final controller = FutureFaceCompareController(lifestyleService: service);

      final result = await controller.loadLatestFutureFaceImages();

      expect(result.futureImageUrl, isNull);
      expect(result.leftImageUrl, isNull);
      expect(result.simulationPromptText, isEmpty);
      expect(result.errorMessage, 'fetch failed');
    });
  });
}
