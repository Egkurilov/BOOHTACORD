import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';

void main() {
  test('an old scan cannot finish a new account scan', () async {
    final scope = SessionScope();
    final old = Completer<List<MediaDevice>>();
    final current = Completer<List<MediaDevice>>();
    var calls = 0;
    final owner = AudioDeviceController(scope: scope, readRoom: () => null,
        loader: () => calls++ == 0 ? old.future : current.future);
    addTearDown(owner.dispose);
    final oldScan = owner.refreshAudioDevices();
    scope.begin();
    owner.cancelOperations();
    final newScan = owner.refreshAudioDevices();
    old.complete([const MediaDevice('old', 'Old', 'audioinput', 'group')]);
    await oldScan;
    expect(owner.audioDevicesLoading, isTrue);
    expect(owner.audioInputDevices, isEmpty);
    current.complete([const MediaDevice('new', 'New', 'audioinput', 'group')]);
    await newScan;
    expect(owner.audioInputDevices.single.deviceId, 'new');
    expect(owner.audioDevicesLoading, isFalse);
  });
}
