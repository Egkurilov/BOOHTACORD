import 'package:livekit_client/livekit_client.dart';

import 'audio_preferences.dart';
import '../features/voice/audio_profile/profile.dart';
import '../features/voice/audio_profile/capture.dart';

AudioPublishOptions get voiceMicrophonePublishOptions =>
    profilePublishOptions(selectedVoiceAudioProfile);

AudioCaptureOptions voiceAudioCaptureOptions(
  String? deviceId,
  AudioProcessingPreferences processing,
) => VoiceCaptureOptions(AudioCaptureOptions(
  deviceId: deviceId,
  autoGainControl: processing.autoGainControl,
  echoCancellation: processing.echoCancellation,
  noiseSuppression: processing.noiseSuppression,
));
