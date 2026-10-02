import 'package:boohtacord_desktop/src/services/voice_stream_start_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not alert for shares already present on room entry', () {
    final tracker = VoiceStreamStartTracker();

    expect(
      tracker.observe(['account-2'], connected: true, reconnecting: false),
      isNull,
    );
    expect(
      tracker.observe(['account-2'], connected: true, reconnecting: false),
      isNull,
    );
  });

  test('reports only newly started remote shares', () {
    final tracker = VoiceStreamStartTracker();
    tracker.observe([], connected: true, reconnecting: false);

    expect(
      tracker.observe(['account-2'], connected: true, reconnecting: false),
      'account-2',
    );
    expect(
      tracker.observe(['account-2'], connected: true, reconnecting: false),
      isNull,
    );
  });

  test('does not announce a known share restored after reconnect', () {
    final tracker = VoiceStreamStartTracker();
    tracker.observe(['account-2'], connected: true, reconnecting: false);
    tracker.observe([], connected: false, reconnecting: true);

    expect(
      tracker.observe(['account-2'], connected: true, reconnecting: false),
      isNull,
    );
  });

  test('resets baseline after leaving the voice room', () {
    final tracker = VoiceStreamStartTracker();
    tracker.observe(['account-2'], connected: true, reconnecting: false);
    tracker.observe([], connected: false, reconnecting: false);
    tracker.observe(['account-2'], connected: true, reconnecting: false);

    expect(
      tracker.observe(['account-3'], connected: true, reconnecting: false),
      'account-3',
    );
  });
}
