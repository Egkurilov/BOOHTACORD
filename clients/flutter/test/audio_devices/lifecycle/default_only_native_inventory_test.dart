import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('successful native bootstrap waits for concrete ADM inventory', () async {
    final changes = StreamController<List<MediaDevice>>.broadcast();
    final owner = AudioDeviceController(
      readRoom: () => null,
      nativeBootstrap: () async {},
      changes: changes.stream,
      loader: () async => const [
        MediaDevice('default', 'System microphone', 'audioinput', null),
        MediaDevice('default', 'System speakers', 'audiooutput', null),
      ],
    );
    addTearDown(() async {
      owner.dispose();
      await changes.close();
    });

    await owner.bootstrap();
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.initializing);

    changes.add(const [
      MediaDevice('default', 'System microphone', 'audioinput', null),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.initializing);

    changes.add(const [
      MediaDevice('built-in-mic', 'Built-in microphone', 'audioinput', null),
      MediaDevice('built-in-output', 'Built-in speakers', 'audiooutput', null),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
  });
}
