import 'package:biostream/screens/my_info/my_info_visibility_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MyInfoVisibilityHelper', () {
    test('초기 visible 상태에서 intro 재생과 opacity 1을 반환한다', () {
      final helper = MyInfoVisibilityHelper();

      final update = helper.handleVisibilityChange(true);

      expect(update.visibilityValue, 1);
      expect(update.shouldPlayIntro, isTrue);
      expect(update.showBlankCanvas, isFalse);
    });

    test('visible에서 hidden으로 바뀌면 reverse 업데이트를 반환한다', () {
      final helper = MyInfoVisibilityHelper();
      helper.handleVisibilityChange(true);

      final update = helper.handleVisibilityChange(false);

      expect(update.shouldReverse, isTrue);
      expect(update.reverseEpoch, isNotNull);
    });

    test('reverse 완료 후 epoch/가시성 조건이 맞을 때만 blank를 표시한다', () {
      final helper = MyInfoVisibilityHelper();
      helper.handleVisibilityChange(true);
      final hideUpdate = helper.handleVisibilityChange(false);

      final shouldShow = helper.shouldShowBlankCanvasAfterReverse(
        epoch: hideUpdate.reverseEpoch!,
        isVisibleNow: false,
      );

      expect(shouldShow, isTrue);
    });
  });
}
