import '../preferences/microphone.dart';
import '../../../services/audio_preferences.dart';
import 'state.dart';

mixin AudioDeviceMicrophone on AudioDeviceState {
  @override
  Future<void> applyMicrophoneControls({bool? agc}) =>
      nativeMicrophone.configure(
        preferences?.microphone ?? const MicrophoneSettings(),
        vad: microphoneVad,
        agc: agc ?? audioProcessing.autoGainControl,
      );
  Future<void> setMicrophoneSettings(MicrophoneSettings value) =>
      _updateMicrophoneSettings((_) => value);

  Future<void> updateMicrophoneSettings({
    double? vadThresholdDb,
    double? microphoneGainPercent,
  }) => _updateMicrophoneSettings(
    (current) => current.copyWith(
      vadThresholdDb: vadThresholdDb,
      microphoneGainPercent: microphoneGainPercent,
    ),
  );

  Future<void> _updateMicrophoneSettings(
    MicrophoneSettings Function(MicrophoneSettings current) update,
  ) {
    final ticket = scope.capture();
    return nativeNoise.run(() async {
      if (!ticket.isActive || isDisposed) return;
      final currentSettings = preferences;
      late final AudioPreferences settings;
      if (currentSettings == null) {
        final accountId = readAccountId?.call();
        if (accountId == null) {
          audioSettingsError = 'Сначала войдите в аккаунт.';
          notifyListeners();
          return;
        }
        final loaded = await AudioPreferences.open(accountId);
        if (!ticket.isActive ||
            isDisposed ||
            readAccountId?.call() != accountId) {
          return;
        }
        settings = preferences ?? loaded;
        preferences ??= loaded;
      } else {
        settings = currentSettings;
      }
      if (!ticket.isActive || !identical(settings, preferences) || isDisposed) {
        return;
      }
      final previous = settings.microphone;
      final next = update(previous);
      try {
        await settings.setMicrophoneSettings(next);
        if (!ticket.isActive || !identical(settings, preferences) || isDisposed) {
          return;
        }
        if (room != null) await applyMicrophoneControls();
        audioSettingsError = null;
      } catch (_) {
        settings.microphone = previous;
        if (!ticket.isActive || !identical(settings, preferences) || isDisposed) {
          return;
        }
        audioSettingsError = 'Не удалось сохранить настройки микрофона.';
      }
      notifyListeners();
    });
  }
}
