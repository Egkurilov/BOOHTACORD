import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/capture/driver.dart';
import 'package:boohtacord_desktop/src/features/screen/runtime_apply/options.dart';

import 'fixtures.dart';
import 'native_tracks.dart';
export 'native_tracks.dart';

class NativeFixture {
  NativeFixture({
    bool enabled = true,
    ScreenAdaptationOptions? adaptationOptions,
    ScreenShareDriver? actualDriver,
  }) {
    owner = ScreenShareController(
      api,
      scope,
      readRoom: () => room,
      voiceReady: () => true,
      driver: actualDriver ?? driver,
      adaptationOptions:
          adaptationOptions ??
          ScreenAdaptationOptions(
            enabled: enabled,
            calibration: fixtureCalibration(),
            now: () => now,
            readWindow: (observation, binding) {
              observations++;
              return window(now, generation: binding.generation);
            },
          ),
    );
    owner.activeTrack = track;
    owner.phase = ScreenSharePhase.sharing;
    owner.quality = high;
    owner.userQualityCeiling = high;
  }
  final api = ApiClient(
    client: MockClient((_) async => http.Response('{}', 200)),
  );
  final scope = SessionScope(),
      track = FixtureTrack(),
      driver = FixtureDriver();
  FixtureRoom room = FixtureRoom();
  late final ScreenShareController owner;
  double now = 1000;
  int observations = 0;
  Future<void> pressure() async {
    for (final at in [1000.0, 11000.0, 21000.0]) {
      now = at;
      await owner.adaptation.step(
        window(now, generation: owner.metrics.gate.generation),
      );
    }
  }

  void dispose() {
    owner.dispose();
    api.transport.raw.close();
  }
}

class FixtureDriver implements ScreenShareDriver {
  int writes = 0;
  Completer<bool>? pending;
  @override
  Future<bool> updateQuality(
    room,
    track,
    quality,
    dimensions,
    isCurrent,
  ) async {
    writes++;
    final applied = await (pending?.future ?? Future.value(true));
    return applied && isCurrent();
  }

  @override
  Future<void> stop(Room room) async {}
  @override
  Future<void> disableBackground() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
