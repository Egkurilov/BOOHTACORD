import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/runtime_apply/runtime.dart';
import 'package:boohtacord_desktop/src/features/screen/runtime_apply/options.dart';

import 'fixtures.dart';
import 'fixture_port.dart';

void main() {
  test('runtime requires explicit enabled/calibration and keeps ceiling across own write', () async {
    final port = FixturePort();
    var now = 1000.0;
    var runtime = ScreenAdaptationRuntime(
      port,
      const ScreenAdaptationOptions(),
    );
    await runtime.step(window(now));
    expect(port.writes, 0);
    runtime = ScreenAdaptationRuntime(
      port,
      ScreenAdaptationOptions(
        enabled: true,
        calibration: fixtureCalibration(),
        now: () => now,
      ),
    );
    for (final at in [1000.0, 11000.0, 21000.0]) {
      now = at;
      await runtime.step(window(at));
    }
    expect(port.writes, 1);
    expect(runtime.state!.current, low);
    expect(runtime.state!.ceiling, high);
    for (final at in [31000.0, 41000.0, 51000.0]) {
      now = at;
      await runtime.step(window(at, pressure: false));
    }
    expect(port.writes, 2);
    expect(runtime.state!.current, high);
  });
  test('late writer/manual/session/room/generation cannot commit stale runtime state', () async {
    for (final boundary in [
      'manual',
      'session',
      'room',
      'generation',
      'stop',
    ]) {
      final port = FixturePort(), pending = Completer<bool>();
      var now = 1000.0;
      port.pending = pending;
      final runtime = ScreenAdaptationRuntime(
        port,
        ScreenAdaptationOptions(
          enabled: true,
          calibration: fixtureCalibration(),
          now: () => now,
        ),
      );
      await runtime.step(window(now));
      now = 11000;
      await runtime.step(window(now));
      now = 21000;
      final applying = runtime.step(window(now));
      await Future<void>.delayed(Duration.zero);
      if (boundary == 'manual') {
        port.manual++;
        runtime.invalidate();
      }
      if (boundary == 'session') port.scope.close();
      if (boundary == 'room') port.room = Object();
      if (boundary == 'generation') port.generation++;
      if (boundary == 'stop') port.stopped = true;
      pending.complete(true);
      await applying;
      expect(runtime.state, isNull, reason: boundary);
    }
  });
}
