import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../voice_scope/api.dart';
import '../../voice_scope/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('room reconnect keeps selected input and output instead of defaults', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final harness = VoiceHarness();
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await harness.dispose();
    });
    harness.enumeratedDevices = const [
      MediaDevice('default-input', 'Default microphone', 'audioinput', null),
      MediaDevice('saved-input', 'USB microphone', 'audioinput', null),
      MediaDevice('default-output', 'Default speakers', 'audiooutput', null),
      MediaDevice('saved-output', 'USB speakers', 'audiooutput', null),
    ];
    harness.audio
      ..applyAudioDevices(harness.enumeratedDevices)
      ..selectedAudioInputId = 'saved-input'
      ..selectedAudioOutputId = 'saved-output';
    harness.api.credential.complete(('lease', credential));

    final joining = harness.owner.joinVoice(channel, listenerOnly: true);
    await harness.room.connectStarted.future;
    expect(
      harness.createdRoomOptions?.defaultAudioCaptureOptions.deviceId,
      'saved-input',
    );
    expect(
      harness.createdRoomOptions?.defaultAudioOutputOptions.deviceId,
      'saved-output',
    );

    harness.room.connecting.complete();
    await joining;
    harness.room.events.emit(const RoomReconnectedEvent());
    await Future<void>.delayed(Duration.zero);

    expect(harness.audio.selectedAudioInputId, 'saved-input');
    expect(harness.audio.selectedAudioOutputId, 'saved-output');
    expect(harness.audio.captureOptions.deviceId, 'saved-input');
    expect(
      harness.owner.voiceRoomOptions().defaultAudioOutputOptions.deviceId,
      'saved-output',
    );
  });
}
