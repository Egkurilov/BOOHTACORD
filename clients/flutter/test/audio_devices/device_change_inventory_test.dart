import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('device-change stream applies hotplug fallback and warning', () async {
    final changes = StreamController<List<MediaDevice>>.broadcast();
    final owner = AudioDeviceController(
      readRoom: () => null,
      changes: changes.stream,
      loader: () async => const [
        MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
        MediaDevice('built-in-mic', 'Built-in microphone', 'audioinput', null),
        MediaDevice('usb-output', 'USB output', 'audiooutput', null),
      ],
    )
      ..selectedAudioInputId = 'usb-mic'
      ..selectedAudioOutputId = 'usb-output';
    addTearDown(() async {
      owner.dispose();
      await changes.close();
    });

    await owner.bootstrap();
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
    expect(owner.selectedAudioInputId, 'usb-mic');

    changes.add(const [
      MediaDevice('built-in-mic', 'Built-in microphone', 'audioinput', null),
      MediaDevice('usb-output', 'USB output', 'audiooutput', null),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(owner.selectedAudioInputId, 'built-in-mic');
    expect(owner.selectedAudioOutputId, 'usb-output');
    expect(owner.audioDeviceWarning, contains('микрофон отключён'));
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
  });
}
