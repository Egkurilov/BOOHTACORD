import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/sample.dart';

import 'native_fixture.dart';
import 'fixtures.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('actual getStats captures binding before async read and rejects all late owners', () async {
    for (final boundary in [
      'manual',
      'server',
      'session',
      'room',
      'track',
      'generation',
      'dispose',
    ]) {
      final f = NativeFixture(), sender = PendingSender();
      f.track.rtpSender = sender;
      f.room.participant.publications = [FixturePublication(f.track, 'screen')];
      f.owner.metrics.track = f.track;
      final sampling = f.owner.metrics.sample(
        f.track,
        f.owner.metrics.gate.generation,
      );
      await Future<void>.delayed(Duration.zero);
      if (boundary == 'manual') await f.owner.updateScreenShareQuality(low);
      if (boundary == 'server') f.api.transport.session.serverRevision++;
      if (boundary == 'session') f.scope.begin();
      if (boundary == 'room') f.room = FixtureRoom();
      if (boundary == 'track') f.owner.activeTrack = FixtureTrack();
      if (boundary == 'generation') f.owner.metrics.gate.nextGeneration();
      if (boundary == 'dispose') f.owner.dispose();
      sender.pending.complete([]);
      await sampling;
      await Future<void>.delayed(Duration.zero);
      expect(f.observations, 0, reason: boundary);
      expect(f.driver.writes, boundary == 'manual' ? 1 : 0, reason: boundary);
      if (boundary != 'dispose') f.dispose();
    }
  });
}

class PendingSender implements rtc.RTCRtpSender {
  final pending = Completer<List<rtc.StatsReport>>();
  @override
  Future<List<rtc.StatsReport>> getStats() => pending.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
