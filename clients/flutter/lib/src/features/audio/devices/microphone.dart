import '../preferences/microphone.dart';
import 'state.dart';
mixin AudioDeviceMicrophone on AudioDeviceState {
  Future<void> applyMicrophoneControls({bool? agc}) => nativeMicrophone.configure(
    preferences?.microphone ?? const MicrophoneSettings(),
    vad: microphoneVad, agc: agc ?? audioProcessing.autoGainControl,
  );
  Future<void> setMicrophoneSettings(MicrophoneSettings value) {
    final ticket = scope.capture();
    final settings = preferences;
    return nativeNoise.run(() async {
      if (!ticket.isActive || !identical(settings, preferences) || isDisposed) return;
      if (settings == null) { audioSettingsError = 'Сначала войдите в аккаунт.'; notifyListeners(); return; }
      final previous = settings.microphone;
      try {
        await settings.setMicrophoneSettings(value);
        if (!ticket.isActive || !identical(settings, preferences) || isDisposed) return;
        if (room != null) await applyMicrophoneControls();
        audioSettingsError = null;
      } catch (_) {
        settings.microphone = previous;
        if (!ticket.isActive || !identical(settings, preferences) || isDisposed) return;
        audioSettingsError = 'Не удалось сохранить настройки микрофона.';
      }
      notifyListeners();
    });
  }
}
