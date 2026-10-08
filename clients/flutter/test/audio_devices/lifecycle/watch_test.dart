import 'dart:async';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('repeated bootstrap keeps one inventory change subscription', () async {
    final changes = StreamController<List<MediaDevice>>.broadcast();
    final owner = AudioDeviceController(
      readRoom: () => null,
      changes: changes.stream,
      loader: () async => const [
        MediaDevice('built-in', 'Built-in microphone', 'audioinput', null),
      ],
    );
    var notifications = 0;
    owner.addListener(() => notifications++);
    addTearDown(() async {
      owner.dispose();
      await changes.close();
    });

    await owner.bootstrap();
    final firstSubscription = owner.subscription;
    await owner.bootstrap();
    expect(owner.subscription, same(firstSubscription));

    notifications = 0;
    changes.add(const [
      MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 1);
    expect(owner.audioInputDevices.single.deviceId, 'usb-mic');
  });
}
