import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('concurrent refresh callers share one inventory scan and result', () async {
    final scan = Completer<List<MediaDevice>>();
    var calls = 0;
    final owner = AudioDeviceController(
      readRoom: () => null,
      loader: () {
        calls++;
        return scan.future;
      },
    );
    addTearDown(owner.dispose);

    final first = owner.refreshAudioDevices();
    final second = owner.refreshAudioDevices();
    expect(calls, 1);
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.initializing);

    scan.complete(const [
      MediaDevice('built-in-mic', 'Built-in microphone', 'audioinput', null),
    ]);
    await Future.wait([first, second]);

    expect(calls, 1);
    expect(owner.audioInputDevices.single.deviceId, 'built-in-mic');
    expect(owner.audioDeviceScanStatus, AudioDeviceScanStatus.ready);
  });
}
