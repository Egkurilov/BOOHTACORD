import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test('retry budget stops automatic attempts and one manual retry replaces generation', () async {
    final h = RosterHarness();
    addTearDown(h.owner.dispose);
    h.owner.start();
    for (var attempt = 0; attempt < 3; attempt++) {
      h.api.streams.last.completeError(
        const ApiFailure('unavailable', status: 503),
      );
      await h.flush();
      if (attempt < 2) {
        h.timers.last.fire();
        await h.flush();
      }
    }
    expect(h.api.streams, hasLength(3));
    expect(h.owner.watching, isFalse);
    expect(h.owner.canRetry, isTrue);
    expect(
      h.timers.where(
        (t) => t.isActive && t.delay != const Duration(seconds: 10),
      ),
      isEmpty,
    );
    final old = h.owner.revision;
    h.owner.retryVoiceRosters();
    h.owner.retryVoiceRosters();
    expect(h.api.streams, hasLength(4));
    expect(h.owner.revision, greaterThan(old));
    expect(h.owner.phase, VoiceRosterPhase.initialLoading);
    h.owner.stop();
    h.api.streams.last.completeError(const ApiFailure('closed'));
    await h.flush();
  });
  test(
    '401 expires without retries; 403 clears roster and stops retries',
    () async {
      for (final status in [401, 403]) {
        final h = RosterHarness();
        var expired = false;
        h.api.onUnauthorized = () => expired = true;
        h.owner.start();
        h.api.streams.single.completeError(
          ApiFailure('denied', status: status),
        );
        await h.flush();
        expect(h.owner.voiceRosters, isNull);
        expect(h.owner.watching, isFalse);
        expect(expired, status == 401);
        expect(
          h.owner.phase,
          status == 401
              ? VoiceRosterPhase.sessionExpired
              : VoiceRosterPhase.unavailable,
        );
        expect(h.owner.retryTimer, isNull);
        h.owner.dispose();
      }
    },
  );
  test(
    'logout clears data and cancels all timers and stream callbacks',
    () async {
      final h = RosterHarness();
      h.owner.start();
      final stream = await h.connect();
      h.snapshot(stream);
      await h.flush();
      h.scope.close();
      h.owner.stop();
      h.snapshot(stream);
      await h.flush();
      expect(h.owner.voiceRosters, isNull);
      expect(h.owner.voiceRosterError, isNull);
      expect(h.timers.where((t) => t.isActive), isEmpty);
      h.owner.dispose();
      await stream.close();
    },
  );
}
