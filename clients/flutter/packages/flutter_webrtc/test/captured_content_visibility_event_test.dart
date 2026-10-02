import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/src/native/event_channel.dart';

void main() {
  group('CapturedContentVisibilityEvent', () {
    test('parses Android visibility events', () {
      final event = CapturedContentVisibilityEvent.fromChannelEvent({
        'onCapturedContentVisibilityChanged': {
          'event': 'onCapturedContentVisibilityChanged',
          'trackId': 'screen-1',
          'isVisible': false,
        },
      });

      expect(event, isNotNull);
      expect(event!.trackId, 'screen-1');
      expect(event.isVisible, isFalse);
    });

    test('ignores unrelated and malformed events', () {
      expect(
        CapturedContentVisibilityEvent.fromChannelEvent({
          'onTrackEnded': {'trackId': 'screen-1'},
        }),
        isNull,
      );
      expect(
        CapturedContentVisibilityEvent.fromChannelEvent({
          'onCapturedContentVisibilityChanged': {
            'trackId': 'screen-1',
            'isVisible': 'false',
          },
        }),
        isNull,
      );
    });
  });
}
