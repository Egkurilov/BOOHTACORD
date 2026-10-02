import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/android_audio_devices.dart';
import 'state.dart';

mixin AudioDeviceSelection on AudioDeviceState {
  Future<void> selectAudioInput(String deviceId) {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    return nativeNoise.run(() async {
      if (!ticket.isActive ||
          !identical(settings, preferences) ||
          !identical(targetRoom, room) ||
          isDisposed) {
        return;
      }
      await _selectAudioInput(deviceId);
    });
  }

  Future<void> _selectAudioInput(String deviceId) async {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    bool current() =>
        !isDisposed &&
        ticket.isActive &&
        identical(settings, preferences) &&
        identical(targetRoom, room);
    if (!current()) return;

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
        await track.mute(stopOnMute: false);
        await nativeNoise.reset();
        await track.setDeviceId(deviceId);
        if (current() && !microphoneMutedIntent) {
          await track.unmute(stopOnMute: false);
        }
        if (!current()) return;
      } else if (room != null) {
        await room!.setAudioInputDevice(device);
        if (!current()) return;
      } else {
        await Hardware.instance.selectAudioInput(device);
        if (!current()) return;
      }
      if (!current()) return;
      selectedAudioInputId = device.deviceId;
      await settings?.setInputDevice(device.deviceId);
      if (!current()) return;
      audioSettingsError = null;
    } catch (cause) {
      if (!current()) return;
      selectedAudioInputId = previous;
      audioSettingsError =
          'Не удалось переключить микрофон: ${cause.runtimeType}.';
    }
    if (current()) notifyListeners();
  }

  Future<void> selectAudioOutput(String deviceId) async {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    bool current() =>
        !isDisposed &&
        ticket.isActive &&
        identical(settings, preferences) &&
        identical(targetRoom, room);
    if (!current()) return;

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
        if (!current()) return;
      } else if (room != null) {
        await AndroidAudioDevices.clearNativeOutput();
        if (!current()) return;
        await room!.setAudioOutputDevice(device);
        if (!current()) return;
      } else {
        await AndroidAudioDevices.clearNativeOutput();
        if (!current()) return;
        await Hardware.instance.selectAudioOutput(device);
        if (!current()) return;
      }
      if (!current()) return;
      selectedAudioOutputId = device.deviceId;
      await settings?.setOutputDevice(device.deviceId);
      if (!current()) return;
      audioSettingsError = null;
    } catch (cause) {
      if (!current()) return;
      selectedAudioOutputId = previous;
      audioSettingsError =
          'Не удалось переключить динамик: ${cause.runtimeType}.';
    }
    if (current()) notifyListeners();
  }
}
