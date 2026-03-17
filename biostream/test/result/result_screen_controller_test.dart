import 'package:biostream/screens/result/result_screen_controller.dart';
import 'package:biostream/services/lifestyle_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLifestyleService extends LifestyleService {
  Map<String, dynamic> lifestyleDataResponse = const {
    'success': true,
    'data': {
      'lifestyle_id': 1,
      'images': {
        'original_image_url': 'https://example.com/original.jpg',
        'generated_image_url': 'https://example.com/generated.jpg',
      },
    },
  };
  Map<String, dynamic> generateReportResponse = const {
    'success': true,
    'report': {
      'tabs': ['goals'],
      'sections': {}
    },
  };
  final List<bool> forceFlags = [];

  @override
  Future<Map<String, dynamic>> getLifestyleData() async {
    return lifestyleDataResponse;
  }

  @override
  Future<Map<String, dynamic>> generateHealthReport(
    int lifestyleId, {
    bool force = false,
    String? situationText,
  }) async {
    forceFlags.add(force);
    return generateReportResponse;
  }
}

void main() {
  group('ResultScreenController', () {
    test('loadLifestyleData 성공 시 이미지 URL을 포함해 반환한다', () async {
      final fakeService = _FakeLifestyleService();
      final controller = ResultScreenController(
        lifestyleService: fakeService,
        situationText: null,
      );

      final result = await controller.loadLifestyleData();

      expect(result.success, isTrue);
      expect(result.lifestyleData?['lifestyle_id'], 1);
      expect(result.originalImageUrl, 'https://example.com/original.jpg');
      expect(result.generatedImageUrl, 'https://example.com/generated.jpg');
    });

    test('generateHealthReport는 lifestyle_id가 없으면 실패한다', () async {
      final controller = ResultScreenController(
        lifestyleService: _FakeLifestyleService(),
        situationText: null,
      );

      final result = await controller.generateHealthReport(
        lifestyleData: const {},
        currentLifestyleData: const {},
        showRegenerateDialog: () async => false,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('설문조사 데이터를 찾을 수 없습니다'));
    });

    test('generateHealthReport token_expired를 전달한다', () async {
      final fakeService = _FakeLifestyleService()
        ..generateReportResponse = const {
          'success': false,
          'token_expired': true,
        };
      final controller = ResultScreenController(
        lifestyleService: fakeService,
        situationText: null,
      );

      final result = await controller.generateHealthReport(
        lifestyleData: const {'lifestyle_id': 10},
        currentLifestyleData: const {'lifestyle_id': 10},
        showRegenerateDialog: () async => false,
      );

      expect(result.success, isFalse);
      expect(result.tokenExpired, isTrue);
    });

    test('already_exists + 재생성 동의 시 force=true로 재호출한다', () async {
      final fakeService = _FakeLifestyleService()
        ..generateReportResponse = {
          'success': true,
          'already_exists': true,
          'report': {
            'tabs': ['goals'],
            'sections': {}
          },
        };
      final controller = ResultScreenController(
        lifestyleService: fakeService,
        situationText: null,
      );

      final result = await controller.generateHealthReport(
        lifestyleData: const {'lifestyle_id': 12},
        currentLifestyleData: const {'lifestyle_id': 12},
        showRegenerateDialog: () async => true,
      );

      expect(result.success, isTrue);
      expect(fakeService.forceFlags, [false, true]);
    });

    test('구 스키마 report는 신 스키마로 변환한다', () async {
      final fakeService = _FakeLifestyleService()
        ..generateReportResponse = {
          'success': true,
          'report': {'legacy': true},
          'cards': [
            {'content': '수면 부족'},
          ],
        };
      final controller = ResultScreenController(
        lifestyleService: fakeService,
        situationText: null,
      );

      final result = await controller.generateHealthReport(
        lifestyleData: const {'lifestyle_id': 8},
        currentLifestyleData: const {'lifestyle_id': 8},
        showRegenerateDialog: () async => false,
      );

      expect(result.success, isTrue);
      expect(result.reportData?['tabs'], isNotEmpty);
      expect(result.reportData?['sections'], isA<Map<String, dynamic>>());
    });
  });
}
