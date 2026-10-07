import 'package:livekit_client/livekit_client.dart';

import '../../../../services/android_audio_devices.dart';
import '../state.dart';

mixin AudioOutputSelection on AudioDeviceState {
  Future<void> selectAudioOutput(String deviceId) async {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    bool current() =>
        !isDisposed &&
        ticket.isActive &&
        identical(settings, preferences) &&
        identical(targetRoom, room);
    final device = audioOutputDevices
        .where(
          (candidate) =>
              candidate.deviceId == deviceId ||
              (deviceId.isEmpty && candidate.deviceId == 'default'),
        )
        .firstOrNull;
    if (audioOutputSwitching || !current() || device == null) return;

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
}
