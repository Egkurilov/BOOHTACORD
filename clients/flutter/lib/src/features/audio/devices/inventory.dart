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
    if (audioInputDevices.isNotEmpty &&
        selectedAudioInputId != null &&
        !audioInputDevices.any(
          (device) => device.deviceId == selectedAudioInputId,
        )) {
      if (selectedAudioInputId != 'default') {
        audioDeviceWarning = 'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.';
      }
      selectedAudioInputId = audioInputDevices.first.deviceId;
    }
    if (audioOutputDevices.isNotEmpty &&
        selectedAudioOutputId != null &&
        !audioOutputDevices.any(
          (device) => device.deviceId == selectedAudioOutputId,
        )) {
      if (selectedAudioOutputId != 'default') {
        audioDeviceWarning = 'Выбранный динамик отключён. Выберите доступное устройство и проверьте звук.';
      }
      selectedAudioOutputId = audioOutputDevices.first.deviceId;
    }
  }
}
