import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:boohtacord_desktop/src/features/voice/admission/join.dart';
import 'api.dart';
import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('macOS bootstraps and resolves audio choices before room creation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    var nativeReady = false;
    final h = VoiceHarness(
      nativeBootstrap: () async {
        nativeReady = true;
      },
    );
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await h.dispose();
    });
    h.audio
      ..selectedAudioInputId = 'default'
      ..selectedAudioOutputId = 'default';
    h.enumeratedDevices = const [
      MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
      MediaDevice('usb-speaker', 'USB speaker', 'audiooutput', null),
    ];
    h.api.credential.complete(('lease', credential));

    final joining = h.owner.joinVoice(channel, listenerOnly: true);
    await Future<void>.delayed(Duration.zero);

    expect(nativeReady, isTrue);
    expect(h.audioScans, 1);
    expect(h.room.connectCalled, isTrue);
    expect(
      h.createdRoomOptions?.defaultAudioCaptureOptions.deviceId,
      'usb-mic',
    );
    expect(
      h.createdRoomOptions?.defaultAudioOutputOptions.deviceId,
      'usb-speaker',
    );
    expect(h.audio.selectedAudioInputId, 'usb-mic');
    expect(h.audio.selectedAudioOutputId, 'usb-speaker');
    expect(h.audio.audioDeviceWarning, isNotNull);

    h.room.connecting.complete();
    await joining;
  });

  test('post-connect fallback reapplies output on platforms without bootstrap', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const webrtcChannel = MethodChannel('FlutterWebRTC.Method');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(webrtcChannel, (call) async {
          expect({'initialize', 'selectAudioOutput'}, contains(call.method));
          return null;
        });
    final h = VoiceHarness();
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(webrtcChannel, null);
      debugDefaultTargetPlatformOverride = null;
      await h.dispose();
    });
    h.audio
      ..selectedAudioInputId = 'default'
      ..selectedAudioOutputId = 'default';
    h.enumeratedDevices = const [
      MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
      MediaDevice('usb-speaker', 'USB speaker', 'audiooutput', null),
    ];
    h.api.credential.complete(('lease', credential));

    final joining = h.owner.joinVoice(channel, listenerOnly: true);
    await Future<void>.delayed(Duration.zero);

    expect(h.room.connectCalled, isTrue);
    expect(
      h.createdRoomOptions?.defaultAudioCaptureOptions.deviceId,
      'default',
    );
    expect(h.createdRoomOptions?.defaultAudioOutputOptions.deviceId, 'default');

    h.room.connecting.complete();
    await joining;
    expect(h.error, isNull);
    expect(h.audio.selectedAudioInputId, 'usb-mic');
    expect(h.audio.captureOptions.deviceId, 'usb-mic');
    expect(h.audio.selectedAudioOutputId, 'usb-speaker');
    expect(h.room.selectedOutput?.deviceId, 'usb-speaker');
    expect(h.audio.audioDeviceWarning, isNotNull);
  });
}
