import '../input_selection/selection.dart';
import '../output_selection/selection.dart';
import '../state.dart';

mixin AudioDevicePreJoinRestore
    on AudioDeviceState, AudioInputSelection, AudioOutputSelection {
  Future<void> applySavedSelectionsBeforeJoin() async {
    if (room != null || audioDeviceScanStatus != AudioDeviceScanStatus.ready) {
      return;
    }
    final inventoryWarning = audioDeviceWarning;
    var selectionCleared = false;
    final inputId = selectedAudioInputId;
    if (inputId != null) {
      if (audioInputDevices.any((device) => device.deviceId == inputId)) {
        await selectAudioInput(inputId);
      } else if (audioInputDevices.isEmpty) {
        selectedAudioInputId = null;
        audioDeviceWarning =
            'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.';
        selectionCleared = true;
      }
    }
    final outputId = selectedAudioOutputId;
    if (outputId != null) {
      if (audioOutputDevices.any((device) => device.deviceId == outputId)) {
        await selectAudioOutput(outputId);
      } else if (audioOutputDevices.isEmpty) {
        selectedAudioOutputId = null;
        audioDeviceWarning =
            'Выбранный динамик отключён. Выберите доступное устройство и проверьте звук.';
        selectionCleared = true;
      }
    }
    if (inventoryWarning != null) audioDeviceWarning = inventoryWarning;
    if (selectionCleared) notifyListeners();
  }
}
