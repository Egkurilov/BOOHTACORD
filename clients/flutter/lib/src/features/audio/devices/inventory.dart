import 'package:livekit_client/livekit_client.dart';

import 'state.dart';

mixin AudioDeviceInventory on AudioDeviceState {
  @override
  void applyAudioDevices(List<MediaDevice> devices) {
    audioInputDevices = devices
        .where((device) => device.kind == 'audioinput')
        .toList(growable: false);
    audioOutputDevices = devices
        .where((device) => device.kind == 'audiooutput')
        .toList(growable: false);
    if (audioDeviceScanStatus != AudioDeviceScanStatus.ready ||
        (audioInputDevices.isEmpty && audioOutputDevices.isEmpty)) {
      return;
    }
    if (selectedAudioInputId != null &&
        !audioInputDevices.any(
          (device) => device.deviceId == selectedAudioInputId,
        )) {
      audioDeviceWarning =
          'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.';
      selectedAudioInputId = audioInputDevices.isEmpty
          ? null
          : audioInputDevices.first.deviceId;
    }
    if (selectedAudioOutputId != null &&
        !audioOutputDevices.any(
          (device) => device.deviceId == selectedAudioOutputId,
        )) {
      audioDeviceWarning =
          'Выбранный динамик отключён. Выберите доступное устройство и проверьте звук.';
      selectedAudioOutputId = audioOutputDevices.isEmpty
          ? null
          : audioOutputDevices.first.deviceId;
    }
  }
}
