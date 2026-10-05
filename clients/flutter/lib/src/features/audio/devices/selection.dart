import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/android_audio_devices.dart';
import '../../../services/client_telemetry.dart';
import 'state.dart';

mixin AudioDeviceSelection on AudioDeviceState {
  Future<void> selectAudioInput(String deviceId) {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    if (audioInputSwitching ||
        !ticket.isActive ||
        !identical(settings, preferences) ||
        !identical(targetRoom, room) ||
        isDisposed ||
        !_containsDevice(audioInputDevices, deviceId)) {
      return Future<void>.value();
    }
    final revision = ++audioInputSwitchRevision;
    audioInputSwitching = true;
    audioDeviceWarning = null;
    audioSettingsError = null;
    notifyListeners();
    return nativeNoise.run(() async {
      try {
        if (!ticket.isActive ||
            !identical(settings, preferences) ||
            !identical(targetRoom, room) ||
            isDisposed ||
            revision != audioInputSwitchRevision) {
          return;
        }
        await _selectAudioInput(deviceId);
      } finally {
        if (!isDisposed && revision == audioInputSwitchRevision) {
          audioInputSwitching = false;
          notifyListeners();
        }
      }
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
    var switchOutcome = 'error';
    audioDeviceWarning = null;
    try {
      final track = room?.localParticipant
          ?.getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is LocalAudioTrack) {
        final previousOptions = track.currentOptions;
        await track.mute(stopOnMute: false);
        await nativeNoise.reset();
        // setDeviceId only edits options while muted. Explicitly recapture
        // through the SDK so the sender actually changes before unmuting.
        try {
          await track.restartTrack(
            previousOptions.copyWith(deviceId: deviceId),
          );
        } catch (_) {
          if (!current()) {
            await track.stop();
            return;
          }
          try {
            await track.restartTrack(previousOptions);
            if (current() && !microphoneMutedIntent) {
              await track.unmute(stopOnMute: false);
            }
            if (!current()) {
              await track.stop();
              return;
            }
            if (microphoneMutedIntent) await track.mute(stopOnMute: false);
            switchOutcome = 'fallback';
          } catch (_) {
            microphoneMutedIntent = true;
            nativeNoise.failMuted('input-switch-failed');
          }
          rethrow;
        }
        if (!current()) {
          await track.stop();
          return;
        }
        if (current() && !microphoneMutedIntent) {
          await track.unmute(stopOnMute: false);
        }
        if (!current()) {
          await track.stop();
          return;
        }
        if (microphoneMutedIntent) await track.mute(stopOnMute: false);
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
      ClientTelemetry.audioInputSwitch(
        targetRoom == null ? 'prejoin' : 'active',
        'success',
      );
    } catch (cause) {
      if (!current()) return;
      selectedAudioInputId = previous;
      audioSettingsError =
          'Не удалось переключить микрофон: ${cause.runtimeType}.';
      ClientTelemetry.audioInputSwitch(
        targetRoom == null ? 'prejoin' : 'active',
        switchOutcome,
      );
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
    if (audioOutputSwitching ||
        !current() ||
        !_containsDevice(audioOutputDevices, deviceId)) {
      return;
    }

    final device = audioOutputDevices
        .where(
          (candidate) =>
              candidate.deviceId == deviceId ||
              (deviceId.isEmpty && candidate.deviceId == 'default'),
        )
        .firstOrNull;
    if (device == null) return;
    final previous = selectedAudioOutputId;
    final revision = ++audioOutputSwitchRevision;
    audioOutputSwitching = true;
    audioDeviceWarning = null;
    audioSettingsError = null;
    notifyListeners();
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
    } finally {
      if (!isDisposed && revision == audioOutputSwitchRevision) {
        audioOutputSwitching = false;
        notifyListeners();
      }
    }
  }

  bool _containsDevice(List<MediaDevice> devices, String deviceId) =>
      devices.any(
        (candidate) =>
            candidate.deviceId == deviceId ||
            (deviceId.isEmpty && candidate.deviceId == 'default'),
      );
}
