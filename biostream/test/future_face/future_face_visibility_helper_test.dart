import 'package:biostream/screens/future_face/future_face_visibility_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FutureFaceVisibilityHelper', () {
    test('initial visible state sets opacity to 1 and plays intro', () {
      final helper = FutureFaceVisibilityHelper();

      final update = helper.handleVisibilityChange(true);

      expect(update.visibilityValue, 1);
      expect(update.shouldPlayIntro, isTrue);
      expect(helper.showBlankCanvas, isFalse);
    });

    test('visible -> hidden triggers reverse with epoch', () {
      final helper = FutureFaceVisibilityHelper();
      helper.handleVisibilityChange(true);

      final hideUpdate = helper.handleVisibilityChange(false);

      expect(hideUpdate.shouldReverse, isTrue);
      expect(hideUpdate.reverseEpoch, isNotNull);
    });

    test('showBlankCanvasAfterReverse only true for matching hidden epoch', () {
      final helper = FutureFaceVisibilityHelper();
      helper.handleVisibilityChange(true);
      final hideUpdate = helper.handleVisibilityChange(false);

      final shouldShow = helper.shouldShowBlankCanvasAfterReverse(
        epoch: hideUpdate.reverseEpoch!,
        isVisibleNow: false,
      );

      expect(shouldShow, isTrue);
      expect(helper.showBlankCanvas, isTrue);
    });
  });
}
