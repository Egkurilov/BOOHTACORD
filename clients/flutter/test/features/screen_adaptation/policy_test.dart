import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/screen/slow_policy/types.dart';
import 'package:boohtacord_desktop/src/features/screen/slow_policy/state.dart';
import 'package:boohtacord_desktop/src/features/screen/slow_policy/evaluate.dart';

import 'fixtures.dart';

void main() {
  test('no calibration/default evidence is inert, consecutive shared pressure downgrades', () {
    var state = ScreenAdaptationState(high, high, 1);
    expect(
      evaluateScreenAdaptation(state, window(1000), 1000, null).reason,
      'disabled-unvalidated',
    );
    final calibration = fixtureCalibration();
    for (final at in [1000.0, 11000.0, 21000.0]) {
      final result = evaluateScreenAdaptation(
        state,
        window(at),
        at,
        calibration,
      );
      state = result.state;
      if (at == 21000) expect(result.profile, low);
    }
    expect(state.current, low);
    expect(state.ceiling, high);
    expect(state.transitions, 1);
  });
  test('receiver/static/hidden/unknown/no-subscriber and stale windows never write', () {
    final calibration = fixtureCalibration();
    for (final blocked in [
      window(1000, source: ScreenAdaptationSource.static),
      window(1000, visible: false),
      window(1000, warmedUp: false),
      window(1000, subscribers: 0),
      window(1000, subscribers: null),
      window(1000, kind: ScreenBottleneck.receiverDownlinkDecode),
      window(1000, generation: 0),
    ]) {
      var state = ScreenAdaptationState(high, high, 1);
      for (var iteration = 0; iteration < 4; iteration++) {
        final result = evaluateScreenAdaptation(
          state,
          blocked,
          1000,
          calibration,
        );
        state = result.state;
        expect(result.profile, isNull);
      }
    }
    expect(
      evaluateScreenAdaptation(
        ScreenAdaptationState(high, high, 1),
        window(1000),
        15000,
        calibration,
      ).reason,
      'stale-window',
    );
  });
  test('recovery uses sustained clear windows and never exceeds independent ceiling', () {
    var state = ScreenAdaptationState(high, high, 1);
    final calibration = fixtureCalibration();
    for (final at in [1000.0, 11000.0, 21000.0]) {
      state = evaluateScreenAdaptation(
        state,
        window(at),
        at,
        calibration,
      ).state;
    }
    for (final at in [31000.0, 41000.0, 51000.0]) {
      state = evaluateScreenAdaptation(
        state,
        window(at, pressure: false),
        at,
        calibration,
      ).state;
    }
    expect(state.current, high);
    expect(state.ceiling, high);
    expect(state.transitions, 2);
  });
}
