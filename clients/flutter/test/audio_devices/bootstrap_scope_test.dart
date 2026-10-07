import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';

void main() {
  test('a late bootstrap cannot scan after logout and the next login', () async {
    final scope = SessionScope();
    final oldNativeBootstrap = Completer<void>();
    var nativeCalls = 0;
    var scanCalls = 0;
    final owner = AudioDeviceController(
      scope: scope,
      readRoom: () => null,
      nativeBootstrap: () {
        nativeCalls++;
        return nativeCalls == 1
            ? oldNativeBootstrap.future
            : Future<void>.value();
      },
      loader: () async {
        scanCalls++;
        return const [
          MediaDevice(
            'current',
            'Current account microphone',
            'audioinput',
            null,
          ),
        ];
      },
    );
    addTearDown(owner.dispose);

    final oldAccountBootstrap = owner.bootstrap();
    scope.close();
    owner.cancelOperations();
    scope.begin();
    await owner.bootstrap();

    expect(nativeCalls, 2);
    expect(scanCalls, 1);
    oldNativeBootstrap.complete();
    await oldAccountBootstrap;

    expect(scanCalls, 1);
    expect(owner.audioInputDevices.single.deviceId, 'current');
  });
}
