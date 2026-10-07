import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test(
    'default-only inventory is not ready after native bootstrap fails',
    () async {
      final owner = AudioDeviceController(
        readRoom: () => null,
        nativeBootstrap: () =>
            Future<void>.error(StateError('bootstrap failed')),
        loader: () async => const [
          MediaDevice('default', 'System microphone', 'audioinput', null),
          MediaDevice('default', 'System speakers', 'audiooutput', null),
        ],
      );
      addTearDown(owner.dispose);

      await owner.bootstrap();

      expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.error);
      expect(
        owner.audioDeviceScanFailure,
        AudioDeviceScanFailure.initializationFailed,
      );
      expect(owner.audioDeviceScanFailed, isTrue);
      expect(owner.audioInputDevices, hasLength(1));
      expect(owner.audioOutputDevices, hasLength(1));
    },
  );

  test(
    'stays initializing until an authoritative inventory completes',
    () async {
      final nativeReady = Completer<void>();
      final scanStarted = Completer<void>();
      final devices = Completer<List<MediaDevice>>();
      final owner = AudioDeviceController(
        readRoom: () => null,
        nativeBootstrap: () => nativeReady.future,
        loader: () {
          scanStarted.complete();
          return devices.future;
        },
      );
      addTearDown(owner.dispose);

      final bootstrap = owner.bootstrap();
      expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.initializing);

      nativeReady.complete();
      await scanStarted.future;
      expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.initializing);

      devices.complete(const [
        MediaDevice(
          'real-microphone',
          'Built-in microphone',
          'audioinput',
          null,
        ),
      ]);
      await bootstrap;

      expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
    },
  );

  test('one real endpoint remains a ready inventory', () async {
    final owner = AudioDeviceController(
      readRoom: () => null,
      loader: () async => const [
        MediaDevice(
          'built-in-microphone',
          'Built-in microphone',
          'audioinput',
          null,
        ),
      ],
    );
    addTearDown(owner.dispose);

    await owner.bootstrap();

    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
    expect(owner.audioDeviceScanFailed, isFalse);
    expect(owner.audioInputDevices, hasLength(1));
  });
}
