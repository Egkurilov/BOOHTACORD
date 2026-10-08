import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/metrics/sample.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';

import 'fixtures.dart';
import 'native_fixture.dart';

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  test('actual controller adapts only through serialized writer and preserves manual ceiling', () async {
    final f = NativeFixture();
    addTearDown(f.dispose);
    f.room.participant.publications = [FixturePublication(f.track, 'screen')];
    await f.pressure();
    expect(f.driver.writes, 1);
    expect(f.owner.quality, low);
    expect(f.owner.userQualityCeiling, high);
    expect(f.owner.adaptation.state!.current, low);
    await f.owner.updateScreenShareQuality(low);
    expect(f.owner.userQualityCeiling, low);
    expect(f.owner.adaptation.state, isNull);
  });
  test(
    'actual metrics ingress is optional and never infers pressure from FPS',
    () async {
      for (final enabled in [false, true]) {
        final f = NativeFixture(enabled: enabled);
        f.room.participant.publications = [
          FixturePublication(f.track, 'screen'),
        ];
        f.owner.metrics.track = f.track;
        await f.owner.metrics.sample(f.track, f.owner.metrics.gate.generation);
        await Future<void>.delayed(Duration.zero);
        expect(f.observations, enabled ? 1 : 0);
        expect(f.driver.writes, 0);
        f.dispose();
      }
    },
  );
  test('macOS capture restart remains a hold without capture or publication writes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final f = NativeFixture();
    addTearDown(f.dispose);
    f.room.participant.publications = [FixturePublication(f.track, 'screen')];
    await f.pressure();
    expect(f.driver.writes, 0);
    expect(f.owner.quality, high);
    expect(f.owner.captureRestartRequired, false);
    expect(f.owner.adaptation.reason, 'capture-restart-required');
  });
  test('actual pending writer cannot commit after stop/session/deployment/room/manual boundary', () async {
    for (final boundary in ['stop', 'session', 'server', 'room', 'manual']) {
      final f = NativeFixture(), pending = Completer<bool>();
      f.room.participant.publications = [FixturePublication(f.track, 'screen')];
      f.driver.pending = pending;
      for (final at in [1000.0, 11000.0]) {
        f.now = at;
        await f.owner.adaptation.step(
          window(at, generation: f.owner.metrics.gate.generation),
        );
      }
      f.now = 21000;
      final applying = f.owner.adaptation.step(
        window(f.now, generation: f.owner.metrics.gate.generation),
      );
      await Future<void>.delayed(Duration.zero);
      if (boundary == 'stop') await f.owner.stopScreenShare();
      if (boundary == 'session') f.scope.close();
      if (boundary == 'server') f.api.transport.session.serverRevision++;
      if (boundary == 'room') f.room = FixtureRoom();
      if (boundary == 'manual') {
        unawaited(f.owner.updateScreenShareQuality(high));
      }
      pending.complete(true);
      await applying;
      expect(f.owner.adaptation.state, isNull, reason: boundary);
      if (boundary != 'manual') expect(f.owner.quality, high, reason: boundary);
      f.dispose();
    }
  });
}
