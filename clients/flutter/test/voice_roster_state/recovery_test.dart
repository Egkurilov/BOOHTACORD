import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test(
    'initial 503 recovers with bounded backoff, then successful empty is fresh',
    () async {
      final h = RosterHarness();
      addTearDown(h.owner.dispose);
      h.owner.start();
      h.api.streams.single.completeError(
        const ApiFailure('unavailable', status: 503),
      );
      await h.flush();
      expect(h.owner.phase, VoiceRosterPhase.unavailable);
      expect(h.owner.voiceRosters, isNull);
      expect(h.owner.retryTimer, isNotNull);
      expect(h.timers.last.delay, const Duration(seconds: 2));
      h.timers.last.fire();
      await h.flush();
      final stream = await h.connect();
      h.snapshot(stream, empty: true);
      await h.flush();
      expect(h.owner.phase, VoiceRosterPhase.fresh);
      expect(h.owner.voiceRosters, isEmpty);
      expect(h.owner.voiceRosterError, isNull);
      h.owner.stop();
      await stream.close();
    },
  );
  test(
    'unavailable SSE retains snapshot explicitly stale, expires then recovers',
    () async {
      final h = RosterHarness();
      addTearDown(h.owner.dispose);
      h.owner.start();
      final stream = await h.connect();
      h.snapshot(stream);
      await h.flush();
      stream.add(utf8.encode('event: roster-unavailable\ndata: {}\n\n'));
      await h.flush();
      expect(h.owner.phase, VoiceRosterPhase.stale);
      expect(h.owner.voiceRosters, hasLength(1));
      expect(h.owner.voiceRosterError, isNotNull);
      h.timers
          .where((t) => t.delay == const Duration(seconds: 10))
          .single
          .fire();
      expect(h.owner.phase, VoiceRosterPhase.unavailable);
      expect(h.owner.voiceRosters, isNull);
      h.timers.last.fire();
      await h.flush();
      final replacement = await h.connect();
      h.snapshot(replacement);
      await h.flush();
      expect(h.owner.phase, VoiceRosterPhase.fresh);
      h.owner.stop();
      await replacement.close();
      await stream.close();
    },
  );
  test('invalid JSON never fabricates a fresh empty room', () async {
    final h = RosterHarness();
    addTearDown(h.owner.dispose);
    h.owner.start();
    final stream = await h.connect();
    h.snapshot(stream);
    await h.flush();
    stream.add(utf8.encode('data: invalid\n\n'));
    await h.flush();
    expect(h.owner.phase, VoiceRosterPhase.stale);
    expect(h.owner.voiceRosters, hasLength(1));
    h.owner.stop();
    await stream.close();
  });
}
