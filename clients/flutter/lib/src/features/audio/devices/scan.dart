import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/android_audio_devices.dart';
import 'state.dart';
import 'platform.dart';

mixin AudioDeviceScan on AudioDeviceState {
  @override
  Future<void> refreshAudioDevices() async {
    if (isDisposed) return;
    if (audioDevicesLoading) {
      refreshQueued = true;
      return;
    }
    final revision = deviceRevision;
    audioDevicesLoading = true;
    audioDeviceScanFailed = false;
    audioSettingsError = null;
    notifyListeners();
    try {
      final devices = await loader();
      if (!isDisposed && revision == deviceRevision) {
        audioDeviceScanFailed = false;
        applyAudioDevices(devices);
      }
    } catch (cause) {
      if (!isDisposed && revision == deviceRevision) {
        audioDeviceScanFailed = true;
        audioSettingsError =
            'Не удалось получить список аудиоустройств: ${cause.runtimeType}.';
      }
    } finally {
      audioDevicesLoading = false;
      notifyListeners();
      if (!isDisposed && refreshQueued) {
        refreshQueued = false;
        unawaited(refreshAudioDevices());
      }
    }
  }

  @override
  Future<void> applyAndroidAdditions(
    List<MediaDevice> baseDevices,
    int revision,
  ) async {
    if (!AndroidAudioDevices.isAndroid) return;
    final additional = await AndroidAudioDevices.enumerateAdditionalDevices();
    if (isDisposed || revision != deviceRevision) return;
    applyAudioDevices(mergeAudioDeviceLists(baseDevices, additional));
    notifyListeners();
  }

  void refreshAfterMicrophoneCapture() {
    if (refreshAfterCaptureRequested) return;
    refreshAfterCaptureRequested = true;
    unawaited(refreshAudioDevices());
  }
}
