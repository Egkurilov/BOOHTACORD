import 'package:livekit_client/livekit_client.dart';

import 'audio_preferences.dart';

const voiceMicrophonePublishOptions = AudioPublishOptions(
  encoding: AudioEncoding(maxBitrate: 128000),
);

AudioCaptureOptions voiceAudioCaptureOptions(
  String? deviceId,
  AudioProcessingPreferences processing,
) => AudioCaptureOptions(
  deviceId: deviceId,
  autoGainControl: processing.autoGainControl,
  echoCancellation: processing.echoCancellation,
  noiseSuppression: processing.noiseSuppression,
);
