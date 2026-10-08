import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/runtime_apply/runtime.dart';
import 'package:boohtacord_desktop/src/features/screen/runtime_apply/options.dart';
import 'package:boohtacord_desktop/src/features/screen/slow_policy/types.dart';

import 'fixture_port.dart';
import 'fixtures.dart';

import 'package:boohtacord_desktop/src/features/screen/metrics/sender_report.dart';

void main() {
  test(
    'failed writes retain bounded attempts and never commit proposed quality',
    () async {
      final port = FixturePort()..succeeds = false;
      var now = 1000.0;
      final runtime = ScreenAdaptationRuntime(
        port,
        ScreenAdaptationOptions(
          enabled: true,
          calibration: fixtureCalibration(),
          now: () => now,
        ),
      );
      for (var i = 0; i < 24; i++) {
        now = 1000.0 + i * 10000;
        await runtime.step(window(now));
      }
      expect(port.writes, 3);
      expect(runtime.attempts, 3);
      expect(runtime.state!.current, high);
      expect(runtime.reason, 'attempt-limit');
    },
  );
  test(
    'late diagnostic collector cannot invalidate a newer manual generation',
    () async {
      final port = FixturePort();
      var now = 1000.0;
      final runtime = ScreenAdaptationRuntime(
        port,
        ScreenAdaptationOptions(
          enabled: true,
          calibration: fixtureCalibration(),
          now: () => now,
          readWindow: (_, _) => window(now),
        ),
      );
      final old = runtime.collector()!;
      port.manual++;
      runtime.invalidate();
      await runtime.step(window(now));
      expect(runtime.state, isNotNull);
      await old(
        const ScreenAdaptationObservation(
          ScreenShareSenderReport(platform: 'windows_native', state: 'playing'),
          [],
          1000,
        ),
      );
      expect(runtime.state, isNotNull);
      expect(port.writes, 0);
    },
  );
  test('caller mutation cannot rewrite admitted calibration ladders', () async {
    final calibration = fixtureCalibration(), port = FixturePort();
    var now = 1000.0;
    final runtime = ScreenAdaptationRuntime(
      port,
      ScreenAdaptationOptions(
        enabled: true,
        calibration: calibration,
        now: () => now,
      ),
    );
    calibration
        .ladders[ScreenBottleneck.publisherUplink]![ScreenAdaptationContent
            .motion]!
        .clear();
    for (final at in [1000.0, 11000.0, 21000.0]) {
      now = at;
      await runtime.step(window(at));
    }
    expect(port.writes, 1);
    expect(runtime.state!.current, low);
  });
}
