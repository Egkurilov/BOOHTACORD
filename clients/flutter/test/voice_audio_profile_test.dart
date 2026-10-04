import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_profile/generated.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_profile/profile.dart';
import 'package:boohtacord_desktop/src/services/voice_audio_config.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';

void main() {
  tearDown(() => selectVoiceAudioProfile(defaultVoiceAudioProfile));
  test('canonical profile and priority match Web without changing default', () {
    final contract = jsonDecode(File('../../contracts/voice-audio-profile.json').readAsStringSync()) as Map;
    expect(voiceAudioProfiles, contract['profiles']);
    expect(defaultVoiceAudioProfile, contract['default']);
    expect(voiceMicrophonePublishOptions.encoding!.maxBitrate, 128000);
    expect(voiceMicrophonePublishOptions.encoding!.bitratePriority, Priority.high);
    expect(voiceMicrophonePublishOptions.dtx, isTrue);
    expect(voiceMicrophonePublishOptions.red, isTrue);
    final pinned = voiceMicrophonePublishOptions;
    selectVoiceAudioProfile('speech-64-v1');
    expect(voiceMicrophonePublishOptions.encoding!.maxBitrate, 64000);
    expect(pinned.encoding!.maxBitrate, 128000);
  });
  test('copy keeps best-effort format and processing preferences', () {
    final capture = voiceAudioCaptureOptions('mic', const AudioProcessingPreferences(autoGainControl: false));
    final switched = capture.copyWith(deviceId: 'new');
    final constraints = switched.toMediaConstraintsMap();
    expect(switched.deviceId, 'new');
    expect(switched.autoGainControl, isFalse);
    expect(jsonEncode(constraints), contains('48000'));
    expect(jsonEncode(constraints), contains('channelCount'));
  });
}
