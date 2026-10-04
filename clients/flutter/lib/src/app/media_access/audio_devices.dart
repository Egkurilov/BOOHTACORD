import 'package:livekit_client/livekit_client.dart';

import '../../services/audio_preferences.dart';
import '../../services/native_noise_suppression.dart';
import '../composition/owners.dart';

mixin AppAudioDevicesAccess on AppOwners {
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

  bool get audioDevicesLoading => audioDevices.audioDevicesLoading;

  set audioDevicesLoading(bool value) =>
      audioDevices.audioDevicesLoading = value;

  bool get audioDeviceScanFailed => audioDevices.audioDeviceScanFailed;

  set audioDeviceScanFailed(bool value) =>
      audioDevices.audioDeviceScanFailed = value;

  String? get audioSettingsError => audioDevices.audioSettingsError;

  set audioSettingsError(String? value) =>
      audioDevices.audioSettingsError = value;

  String? get audioDeviceWarning => audioDevices.audioDeviceWarning;

  set audioDeviceWarning(String? value) =>
      audioDevices.audioDeviceWarning = value;

  Future<void> refreshAudioDevices() => audioDevices.refreshAudioDevices();

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
