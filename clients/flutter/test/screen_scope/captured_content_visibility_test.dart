import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/src/native/event_channel.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/captured_content_visibility.dart';

void main() {
  group('CapturedContentVisibilityState', () {
    test('only applies events for the currently published capture track', () {
      final state = CapturedContentVisibilityState()..track('screen-current');

      expect(
        state.handle(const CapturedContentVisibilityEvent('screen-old', false)),
        isFalse,
      );
      expect(state.isVisible, isNull);

      expect(
        state.handle(
          const CapturedContentVisibilityEvent('screen-current', false),
        ),
        isTrue,
      );
      expect(state.isVisible, isFalse);
    });

    test('resets visibility when capture changes or stops', () {
      final state = CapturedContentVisibilityState()..track('screen-1');
      state.handle(const CapturedContentVisibilityEvent('screen-1', false));

      state.track('screen-2');
      expect(state.isVisible, isNull);
      expect(
        state.handle(const CapturedContentVisibilityEvent('screen-1', true)),
        isFalse,
      );

      state.track(null);
      expect(state.isVisible, isNull);
      expect(
        state.handle(const CapturedContentVisibilityEvent('screen-2', false)),
        isFalse,
      );
    });
  });
}
