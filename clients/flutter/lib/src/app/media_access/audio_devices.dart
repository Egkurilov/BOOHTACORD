import 'package:livekit_client/livekit_client.dart';

import '../../services/audio_preferences.dart';
import '../../services/native_noise_suppression.dart';
import '../composition/owners.dart';
import '../../features/audio/preferences/microphone.dart';
import '../../features/audio/microphone_controls/native.dart';
import '../../features/audio/devices/state.dart';

mixin AppAudioDevicesAccess on AppOwners {
  MicrophoneSettings get microphoneSettings =>
      audioDevices.preferences?.microphone ?? const MicrophoneSettings();
  NativeMicrophoneControls get microphoneControlsRuntime =>
      audioDevices.nativeMicrophone;
  Future<void> setMicrophoneSettings(MicrophoneSettings next) =>
      audioDevices.setMicrophoneSettings(next);
  Future<void> updateMicrophoneSettings({
    double? vadThresholdDb,
    double? microphoneGainPercent,
  }) => audioDevices.updateMicrophoneSettings(
    vadThresholdDb: vadThresholdDb,
    microphoneGainPercent: microphoneGainPercent,
  );
  List<MediaDevice> get audioInputDevices => audioDevices.audioInputDevices;

  set audioInputDevices(List<MediaDevice> value) =>
      audioDevices.audioInputDevices = value;

  List<MediaDevice> get audioOutputDevices => audioDevices.audioOutputDevices;

  set audioOutputDevices(List<MediaDevice> value) =>
      audioDevices.audioOutputDevices = value;

  String? get selectedAudioInputId => audioDevices.selectedAudioInputId;

  set selectedAudioInputId(String? value) =>
      audioDevices.selectedAudioInputId = value;

  String? get selectedAudioOutputId => audioDevices.selectedAudioOutputId;

  set selectedAudioOutputId(String? value) =>
      audioDevices.selectedAudioOutputId = value;

  NativeNoiseSuppressionState get noiseSuppressionRuntime =>
      audioDevices.nativeNoise.state;

  AudioProcessingPreferences get audioProcessing =>
      audioDevices.audioProcessing;

  set audioProcessing(AudioProcessingPreferences value) =>
      audioDevices.audioProcessing = value;

  bool get audioDevicesLoading =>
      audioDevices.audioDevicesLoading ||
      audioDevices.audioDeviceScanStatus == AudioDeviceScanStatus.initializing;

  set audioDevicesLoading(bool value) =>
      audioDevices.audioDevicesLoading = value;

  bool get audioDeviceScanFailed => audioDevices.audioDeviceScanFailed;

  set audioDeviceScanFailed(bool value) =>
      audioDevices.audioDeviceScanFailed = value;

  AudioDeviceScanStatus get audioDeviceScanStatus =>
      audioDevices.audioDeviceScanStatus;

  AudioDeviceScanFailure? get audioDeviceScanFailure =>
      audioDevices.audioDeviceScanFailure;

  bool get audioInputSwitching => audioDevices.audioInputSwitching;

  bool get audioOutputSwitching => audioDevices.audioOutputSwitching;

  String? get audioSettingsError => audioDevices.audioSettingsError;

  set audioSettingsError(String? value) =>
      audioDevices.audioSettingsError = value;

  String? get audioDeviceWarning => audioDevices.audioDeviceWarning;

  set audioDeviceWarning(String? value) =>
      audioDevices.audioDeviceWarning = value;

  Future<void> refreshAudioDevices() => audioDevices.nativeBootstrap == null
      ? audioDevices.refreshAudioDevices()
      : audioDevices.bootstrap();

  Future<void> selectAudioInput(String deviceId) async {
    final target = voice.room;
    await audioDevices.selectAudioInput(deviceId);
    if (target == null || !identical(target, voice.room)) return;
    final track = target.localParticipant
        ?.getTrackPublicationBySource(TrackSource.microphone)
        ?.track;
    if (audioSettingsError != null && track is LocalAudioTrack && track.muted) {
      voice.microphoneMuted = true;
      if (audioDevices.nativeNoise.state.status == 'error') {
        voice.microphoneUnavailable = true;
      }
      voice.notifyListeners();
    }
  }

  Future<void> selectAudioOutput(String deviceId) =>
      audioDevices.selectAudioOutput(deviceId);

  Future<void> setAudioProcessing(AudioProcessingPreferences next) =>
      audioDevices.setAudioProcessing(next);
}
