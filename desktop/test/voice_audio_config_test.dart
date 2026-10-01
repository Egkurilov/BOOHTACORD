import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/voice_audio_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
