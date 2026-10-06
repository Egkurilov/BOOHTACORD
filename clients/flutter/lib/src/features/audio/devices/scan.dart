import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/android_audio_devices.dart';
import 'state.dart';
import 'platform.dart';

mixin AudioDeviceScan on AudioDeviceState {
  @override
  Future<void> refreshAudioDevices() async {
    final ticket = scope.capture();
    if (isDisposed || !ticket.isActive) return;
    if (audioDevicesLoading) {
      refreshQueued = true;
      final completion = queuedAudioRefreshCompletion ??= Completer<void>();
      await completion.future;
      return;
    }
    final revision = deviceRevision;
    audioDevicesLoading = true;
    audioDeviceScanFailed = false;
    audioSettingsError = null;
    notifyListeners();
    try {
      final devices = await loader();
      if (!isDisposed && ticket.isActive && revision == deviceRevision) {
        audioDeviceScanFailed = false;
        applyAudioDevices(devices);
      }
    } catch (cause) {
      if (!isDisposed && ticket.isActive && revision == deviceRevision) {
        audioDeviceScanFailed = true;
        audioSettingsError =
            'Не удалось получить список аудиоустройств: ${cause.runtimeType}.';
      }
    } finally {
      if (!isDisposed && ticket.isActive) {
        audioDevicesLoading = false;
        notifyListeners();
        if (refreshQueued) {
          refreshQueued = false;
          final completion = queuedAudioRefreshCompletion;
          queuedAudioRefreshCompletion = null;
          try {
            await refreshAudioDevices();
          } finally {
            if (completion != null && !completion.isCompleted) {
              completion.complete();
            }
          }
        }
      }
    }
  }

  @override
  Future<void> applyAndroidAdditions(
    List<MediaDevice> baseDevices,
    int revision,
  ) async {
    final ticket = scope.capture();
    if (!ticket.isActive || !AndroidAudioDevices.isAndroid) return;
    final additional = await AndroidAudioDevices.enumerateAdditionalDevices();
    if (!ticket.isActive || isDisposed || revision != deviceRevision) return;
    applyAudioDevices(mergeAudioDeviceLists(baseDevices, additional));
    notifyListeners();
  }

  void refreshAfterMicrophoneCapture() {
    if (refreshAfterCaptureRequested) return;
    refreshAfterCaptureRequested = true;
    unawaited(refreshAudioDevices());
  }
}
