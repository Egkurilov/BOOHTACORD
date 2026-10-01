import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:boohtacord_desktop/src/services/voice_processing_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

void main() {
  test('Windows recaptures with new noise setting', () async {
    final values = <bool>[];
    await applyVoiceProcessingForPlatform(
      platform: TargetPlatform.windows,
      current: const AudioCaptureOptions(),
      next: const AudioProcessingPreferences(noiseSuppression: false),
      recapture: (options) async => values.add(options.noiseSuppression),
      updateRuntime: (_) async => fail('Windows has no runtime processing API'),
    );
    expect(values, [false]);
  });

  test('Windows restores prior processing after recapture failure', () async {
    final values = <bool>[];
    await expectLater(
      applyVoiceProcessingForPlatform(
        platform: TargetPlatform.windows,
        current: const AudioCaptureOptions(),
        next: const AudioProcessingPreferences(noiseSuppression: false),
        recapture: (options) async {
          values.add(options.noiseSuppression);
          if (!options.noiseSuppression) throw StateError('capture failed');
        },
        updateRuntime: (_) async =>
            fail('Windows has no runtime processing API'),
      ),
      throwsStateError,
    );
    expect(values, [false, true]);
  });

  test('other platforms keep the runtime processing path', () async {
    // ignore: experimental_member_use
    AudioProcessingOptions? applied;
    await applyVoiceProcessingForPlatform(
      platform: TargetPlatform.android,
      current: const AudioCaptureOptions(),
      next: const AudioProcessingPreferences(noiseSuppression: false),
      recapture: (_) async => fail('unexpected recapture'),
      updateRuntime: (options) async => applied = options,
    );
    expect(applied?.noiseSuppression, isFalse);
  });
}
