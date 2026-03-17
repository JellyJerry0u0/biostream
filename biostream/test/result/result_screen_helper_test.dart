import 'package:biostream/screens/result/result_screen_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResultScreenHelper', () {
    test('openExternalUrl은 null/빈값에서 false를 반환한다', () async {
      final nullResult = await ResultScreenHelper.openExternalUrl(null);
      final emptyResult = await ResultScreenHelper.openExternalUrl('   ');

      expect(nullResult, isFalse);
      expect(emptyResult, isFalse);
    });

    test('openExternalUrl은 잘못된 URL에서 false를 반환한다', () async {
      final result = await ResultScreenHelper.openExternalUrl('not-a-url');
      expect(result, isFalse);
    });

    test('extractOriginalImageUrl 우선순위를 따른다', () {
      final lifestyleData = {
        'images': {'original_image_url': 'https://a.com/original.jpg'},
        'original_image_url': 'https://a.com/fallback.jpg',
      };
      final reportData = {
        'original_image_url': 'https://a.com/report.jpg',
      };

      final url = ResultScreenHelper.extractOriginalImageUrl(
        lifestyleData,
        reportData,
      );

      expect(url, 'https://a.com/original.jpg');
    });

    test('isGallerySaveSuccess는 다양한 성공 응답을 인식한다', () {
      expect(ResultScreenHelper.isGallerySaveSuccess(true), isTrue);
      expect(
        ResultScreenHelper.isGallerySaveSuccess({'isSuccess': true}),
        isTrue,
      );
      expect(
        ResultScreenHelper.isGallerySaveSuccess({'success': true}),
        isTrue,
      );
      expect(
        ResultScreenHelper.isGallerySaveSuccess({'filePath': '/tmp/test.jpg'}),
        isTrue,
      );
      expect(
          ResultScreenHelper.isGallerySaveSuccess({'success': false}), isFalse);
    });
  });
}
