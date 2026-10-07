import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('manual retry reinitializes audio and clears a resolved denial', () async {
    var bootstrapCalls = 0;
    final owner = AudioDeviceController(
      readRoom: () => null,
      nativeBootstrap: () async {
        if (bootstrapCalls++ == 0) {
          throw PlatformException(code: 'permissionDenied');
        }
      },
      loader: () async => bootstrapCalls == 1
          ? const [
              MediaDevice('default', 'System microphone', 'audioinput', null),
            ]
          : const [
              MediaDevice(
                'built-in-mic',
                'Built-in microphone',
                'audioinput',
                null,
              ),
            ],
    );
    addTearDown(owner.dispose);

    await owner.bootstrap();
    expect(owner.audioDeviceScanFailure, AudioDeviceScanFailure.permissionDenied);
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.error);

    await owner.bootstrap();

    expect(bootstrapCalls, 2);
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
    expect(owner.audioDeviceScanFailure, isNull);
    expect(owner.audioDeviceScanFailed, isFalse);
    expect(owner.audioDeviceWarning, isNull);
  });

  test('default-only hotplug stays failed until a concrete endpoint appears', () async {
    final changes = StreamController<List<MediaDevice>>.broadcast();
    final owner = AudioDeviceController(
      readRoom: () => null,
      changes: changes.stream,
      nativeBootstrap: () async => throw StateError('bootstrap failed'),
      loader: () async => const [
        MediaDevice('default', 'System microphone', 'audioinput', null),
      ],
    );
    addTearDown(() async {
      owner.dispose();
      await changes.close();
    });

    await owner.bootstrap();
    changes.add(const [
      MediaDevice('default', 'System microphone', 'audioinput', null),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.error);

    changes.add(const [
      MediaDevice('built-in-mic', 'Built-in microphone', 'audioinput', null),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
    expect(owner.audioDeviceScanFailure, isNull);
    expect(owner.audioDeviceScanFailed, isFalse);
  });
}
