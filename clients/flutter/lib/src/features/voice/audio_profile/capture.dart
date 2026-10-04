import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'generated.dart';

/// Ideal constraints are requests, not evidence of the native capture format.
class VoiceCaptureOptions extends AudioCaptureOptions {
  VoiceCaptureOptions(AudioCaptureOptions base) : super(
    deviceId: base.deviceId, noiseSuppression: base.noiseSuppression,
    echoCancellation: base.echoCancellation, autoGainControl: base.autoGainControl,
    highPassFilter: base.highPassFilter, echoCancellationMode: base.echoCancellationMode,
    noiseSuppressionMode: base.noiseSuppressionMode, autoGainControlMode: base.autoGainControlMode,
    highPassFilterMode: base.highPassFilterMode, voiceIsolation: base.voiceIsolation,
    typingNoiseDetection: base.typingNoiseDetection,
    stopAudioCaptureOnMute: base.stopAudioCaptureOnMute, processor: base.processor,
  );
  @override
  Map<String, dynamic> toMediaConstraintsMap() {
    final constraints = super.toMediaConstraintsMap();
    final profile = voiceAudioProfiles.first;
    if (kIsWeb) {
      constraints['sampleRate'] = {'ideal': profile['sampleRate']};
      constraints['channelCount'] = {'ideal': profile['captureChannels']};
    } else {
      final optional = (constraints['optional'] as List?) ?? <Map<String, dynamic>>[];
      constraints['optional'] = [...optional,
        {'sampleRate': profile['sampleRate']},
        {'channelCount': profile['captureChannels']},
      ];
    }
    return constraints;
  }
  @override
  AudioCaptureOptions copyWith({
    String? deviceId, bool? noiseSuppression, bool? echoCancellation,
    bool? autoGainControl, bool? highPassFilter,
    // Preserve the pinned SDK's experimental override signature and values.
    // ignore: experimental_member_use
    AudioProcessingMode? echoCancellationMode, AudioProcessingMode? noiseSuppressionMode,
    // ignore: experimental_member_use
    AudioProcessingMode? autoGainControlMode, AudioProcessingMode? highPassFilterMode,
    // ignore: experimental_member_use
    AudioProcessingOptions? processing, bool? voiceIsolation,
    bool? typingNoiseDetection, bool? stopAudioCaptureOnMute,
    TrackProcessor<AudioProcessorOptions>? processor,
  }) => VoiceCaptureOptions(super.copyWith(
    deviceId: deviceId, noiseSuppression: noiseSuppression,
    echoCancellation: echoCancellation, autoGainControl: autoGainControl,
    highPassFilter: highPassFilter, echoCancellationMode: echoCancellationMode,
    noiseSuppressionMode: noiseSuppressionMode, autoGainControlMode: autoGainControlMode,
    highPassFilterMode: highPassFilterMode, processing: processing,
    voiceIsolation: voiceIsolation, typingNoiseDetection: typingNoiseDetection,
    stopAudioCaptureOnMute: stopAudioCaptureOnMute, processor: processor,
  ));
}
