import 'package:biostream/screens/facescan/facescan_controller.dart';
import 'package:biostream/services/image_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _FakeImageService extends ImageService {
  Map<String, dynamic> uploadResponse = {'success': false};

  @override
  Future<Map<String, dynamic>> uploadImage(
      XFile imageFile, int targetYears) async {
    return uploadResponse;
  }
}

void main() {
  group('FaceScanController', () {
    final dummyImage = XFile('/tmp/dummy.jpg');

    test('업로드 실패 시 메시지를 그대로 반환한다', () async {
      final fakeService = _FakeImageService()
        ..uploadResponse = {'success': false, 'message': '업로드 실패'};
      final controller = FaceScanController(imageService: fakeService);

      final result = await controller.uploadForSurvey(dummyImage);

      expect(result.success, isFalse);
      expect(result.message, '업로드 실패');
      expect(result.originalImageUrl, isNull);
    });

    test('original_image_url이 있으면 해당 URL을 우선 사용한다', () async {
      final fakeService = _FakeImageService()
        ..uploadResponse = {
          'success': true,
          'original_image_url': 'https://example.com/original.jpg',
          'saved_path': '/uploads/fallback.jpg',
          'lifestyle_id': 12,
        };
      final controller = FaceScanController(imageService: fakeService);

      final result = await controller.uploadForSurvey(dummyImage);

      expect(result.success, isTrue);
      expect(result.originalImageUrl, 'https://example.com/original.jpg');
      expect(result.lifestyleId, 12);
    });

    test('original_image_url이 없으면 saved_path를 사용한다', () async {
      final fakeService = _FakeImageService()
        ..uploadResponse = {
          'success': true,
          'saved_path': '/uploads/only_saved.jpg',
        };
      final controller = FaceScanController(imageService: fakeService);

      final result = await controller.uploadForSurvey(dummyImage);

      expect(result.success, isTrue);
      expect(result.originalImageUrl, '/uploads/only_saved.jpg');
    });
  });
}
