import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/android_audio_devices.dart';
import 'state.dart';

mixin AudioDeviceSelection on AudioDeviceState {
  Future<void> selectAudioInput(String deviceId) async {
    final device = audioInputDevices
        .where(
          (candidate) =>
              candidate.deviceId == deviceId ||
              (deviceId.isEmpty && candidate.deviceId == 'default'),
        )
        .firstOrNull;
    if (device == null) return;
    final previous = selectedAudioInputId;
    audioDeviceWarning = null;
    try {
      final track = room?.localParticipant
          ?.getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is LocalAudioTrack) {
        await track.setDeviceId(deviceId);
      } else if (room != null) {
        await room!.setAudioInputDevice(device);
      } else {
        await Hardware.instance.selectAudioInput(device);
      }
      selectedAudioInputId = device.deviceId;
      await preferences?.setInputDevice(device.deviceId);
      audioSettingsError = null;
    } catch (cause) {
      selectedAudioInputId = previous;
      audioSettingsError =
          'Не удалось переключить микрофон: ${cause.runtimeType}.';
    }
    notifyListeners();
  }

  Future<void> selectAudioOutput(String deviceId) async {
    final device = audioOutputDevices
        .where(
          (candidate) =>
              candidate.deviceId == deviceId ||
              (deviceId.isEmpty && candidate.deviceId == 'default'),
        )
        .firstOrNull;
    if (device == null) return;
    final previous = selectedAudioOutputId;
    audioDeviceWarning = null;
    try {
      if (AndroidAudioDevices.isNativeOutputRoute(device.deviceId)) {
        if (room != null &&
            !await AndroidAudioDevices.selectNativeOutput(device.deviceId)) {
          throw StateError('Android не смог переключить аудиовыход.');
        }
      } else if (AndroidAudioDevices.isAndroid &&
          device.deviceId == 'default') {
        await AndroidAudioDevices.clearNativeOutput();
      } else if (room != null) {
        await AndroidAudioDevices.clearNativeOutput();
        await room!.setAudioOutputDevice(device);
      } else {
        await AndroidAudioDevices.clearNativeOutput();
        await Hardware.instance.selectAudioOutput(device);
      }
      selectedAudioOutputId = device.deviceId;
      await preferences?.setOutputDevice(device.deviceId);
      audioSettingsError = null;
    } catch (cause) {
      selectedAudioOutputId = previous;
      audioSettingsError =
          'Не удалось переключить динамик: ${cause.runtimeType}.';
    }
    notifyListeners();
  }
}
