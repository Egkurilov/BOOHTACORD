import '../state.dart';
import 'switch.dart';

mixin AudioInputSelection on AudioDeviceState, AudioInputSwitch {
  Future<void> selectAudioInput(String deviceId) {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    final available = audioInputDevices.any(
      (device) =>
          device.deviceId == deviceId ||
          (deviceId.isEmpty && device.deviceId == 'default'),
    );
    if (audioInputSwitching ||
        !ticket.isActive ||
        !identical(settings, preferences) ||
        !identical(targetRoom, room) ||
        isDisposed ||
        !available) {
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
        await switchAudioInput(deviceId);
      } finally {
        if (!isDisposed && revision == audioInputSwitchRevision) {
          audioInputSwitching = false;
          notifyListeners();
        }
      }
    });
  }
}
