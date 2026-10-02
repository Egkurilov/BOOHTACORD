import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'disposed owner ignores an in-flight device scan and late notification',
    () async {
      final pending = Completer<List<MediaDevice>>();
      final owner = AudioDeviceController(
        readRoom: () => null,
        loader: () => pending.future,
      );
      var notifications = 0;
      owner.addListener(() => notifications++);
      final scan = owner.refreshAudioDevices();
      expect(notifications, 1);
      owner.dispose();
      pending.complete([
        const MediaDevice('mic', 'Microphone', 'audioinput', 'group'),
      ]);
      await scan;
      expect(owner.audioInputDevices, isEmpty);
      expect(notifications, 1);
    },
  );

  test('hotplug inventory supersedes an older pending scan', () async {
    final pending = Completer<List<MediaDevice>>();
    final changes = StreamController<List<MediaDevice>>(sync: true);
    final owner = AudioDeviceController(
      readRoom: () => null,
      loader: () => pending.future,
      changes: changes.stream,
    );
    owner.watch();
    final scan = owner.refreshAudioDevices();
    changes.add([
      const MediaDevice('current', 'Current', 'audioinput', 'group'),
    ]);
    pending.complete([const MediaDevice('old', 'Old', 'audioinput', 'group')]);
    await scan;
    expect(owner.audioInputDevices.single.deviceId, 'current');
    owner.dispose();
    await changes.close();
  });
}
