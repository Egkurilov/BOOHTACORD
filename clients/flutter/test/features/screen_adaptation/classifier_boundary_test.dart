import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/sample.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/runtime_apply/options.dart';
import 'package:boohtacord_desktop/src/features/screen/slow_policy/types.dart';

import 'native_fixture.dart';
import 'fixtures.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('actual async classifier cannot adapt old publication/session/manual intent', () async {
    for (final boundary in [
      'manual',
      'server',
      'session',
      'room',
      'publication',
      'generation',
      'stop',
    ]) {
      final pending = Completer<ScreenAdaptationWindow?>();
      var now = 1000.0, classified = false;
      final f = NativeFixture(
        adaptationOptions: ScreenAdaptationOptions(
          enabled: true,
          calibration: fixtureCalibration(),
          now: () => now,
          readWindow: (_, _) {
            classified = true;
            return pending.future;
          },
        ),
      );
      f.room.participant.publications = [FixturePublication(f.track, 'screen')];
      for (final at in [1000.0, 11000.0]) {
        now = at;
        await f.owner.adaptation.step(window(at, generation: 0));
      }
      now = 21000;
      f.owner.metrics.track = f.track;
      await f.owner.metrics.sample(f.track, 0);
      expect(classified, true);
      if (boundary == 'manual') await f.owner.updateScreenShareQuality(high);
      if (boundary == 'server') f.api.transport.session.serverRevision++;
      if (boundary == 'session') f.scope.begin();
      if (boundary == 'room') f.room = FixtureRoom();
      if (boundary == 'publication') {
        f.room.participant.publications = [FixturePublication(f.track, 'new')];
      }
      if (boundary == 'generation') f.owner.metrics.gate.nextGeneration();
      if (boundary == 'stop') await f.owner.stopScreenShare();
      pending.complete(window(now, generation: 0));
      await Future<void>.delayed(Duration.zero);
      expect(f.driver.writes, boundary == 'manual' ? 1 : 0, reason: boundary);
      expect(f.owner.adaptation.state, isNull, reason: boundary);
      f.dispose();
    }
  });
}
