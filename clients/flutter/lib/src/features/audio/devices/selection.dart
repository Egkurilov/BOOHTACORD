import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
        if (_usesDesktopAudioDeviceModule) {
          // Desktop LiveKit routes input through its Audio Device Module.
          // Restarting getUserMedia does not switch that ADM route reliably;
          // use the room API, which updates both the native route and the
          // room's defaults for any later microphone track.
          await nativeNoise.reset();
          if (!current()) return;
          await targetRoom!.setAudioInputDevice(device);
          if (!current()) return;
          track.currentOptions = track.currentOptions.copyWith(
            deviceId: device.deviceId,
          );
        } else {
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
        }
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
      audioSettingsError = _inputSelectionErrorMessage(cause);
      ClientTelemetry.audioInputSwitch(
        targetRoom == null ? 'prejoin' : 'active',
        switchOutcome,
      );
    }
    if (current()) notifyListeners();
  }

  String _inputSelectionErrorMessage(Object cause) {
    if (cause is PlatformException) {
      switch (cause.code) {
        case 'selectAudioInputFailed':
          return 'Система не смогла переключить микрофон. Проверьте подключение устройства и повторите попытку.';
        case 'audioInputEnumerationFailed':
          return 'Не удалось обновить список аудиоустройств. Повторите попытку.';
      }
    }
    return 'Не удалось переключить микрофон. Повторите попытку.';
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

  bool get _usesDesktopAudioDeviceModule =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
}
