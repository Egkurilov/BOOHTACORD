import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import 'audio_preferences.dart';

Future<void> applyVoiceProcessingForPlatform({
  required TargetPlatform platform,
  required AudioCaptureOptions current,
  required AudioProcessingPreferences next,
  required Future<void> Function(AudioCaptureOptions) recapture,
  // ignore: experimental_member_use
  required Future<void> Function(AudioProcessingOptions) updateRuntime,
}) async {
  // Windows' LiveKit plugin does not implement runtime processing changes.
  if (platform == TargetPlatform.windows) {
    final options = current.copyWith(
      autoGainControl: next.autoGainControl,
      echoCancellation: next.echoCancellation,
      noiseSuppression: next.noiseSuppression,
    );
    try {
      await recapture(options);
    } catch (_) {
      try {
        await recapture(current);
      } catch (_) {}
      rethrow;
    }
    return;
  }

  await updateRuntime(
    // ignore: experimental_member_use
    AudioProcessingOptions(
      autoGainControl: next.autoGainControl,
      echoCancellation: next.echoCancellation,
      noiseSuppression: next.noiseSuppression,
      highPassFilter: false,
    ),
  );
}
