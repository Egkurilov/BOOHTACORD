import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/voice_audio_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/admission/prepare.dart';

import 'voice_scope/fakes.dart';

void main() {
  test('voice admission uses encoding and saved capture settings', () async {
    final harness = VoiceHarness();
    addTearDown(harness.dispose);
    harness.audio.selectedAudioInputId = 'saved-mic';
    harness.audio.audioProcessing = const AudioProcessingPreferences(
      noiseSuppression: false,
    );
    final options = harness.owner.voiceRoomOptions();
    expect(options.defaultAudioPublishOptions.encoding?.maxBitrate, 128000);
    expect(options.defaultAudioCaptureOptions.deviceId, 'saved-mic');
    expect(options.defaultAudioCaptureOptions.noiseSuppression, isFalse);
  });

  test('microphone uses the approved 128 kbit/s upper encoding target', () {
    expect(voiceMicrophonePublishOptions.encoding?.maxBitrate, 128000);
    expect(voiceMicrophonePublishOptions.dtx, isTrue);
  });

  test('capture defaults enable the three processing controls', () {
    final options = voiceAudioCaptureOptions(
      null,
      const AudioProcessingPreferences(),
    );
    expect(options.noiseSuppression, isTrue);
    expect(options.echoCancellation, isTrue);
    expect(options.autoGainControl, isTrue);
  });

  test('capture follows saved processing preferences', () {
    final options = voiceAudioCaptureOptions(
      'mic-1',
      const AudioProcessingPreferences(noiseSuppression: false),
    );
    expect(options.deviceId, 'mic-1');
    expect(options.noiseSuppression, isFalse);
  });
}
