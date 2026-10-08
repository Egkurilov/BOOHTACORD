import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/android_audio_devices.dart';
import 'failure.dart';
import 'platform.dart';
import 'state.dart';

mixin AudioDeviceScan on AudioDeviceState {
  Future<void>? _scanOperation;

  @override
  Future<void> refreshAudioDevices() {
    final pending = _scanOperation;
    if (pending != null) return pending;
    final operation = _refreshAudioDevices();
    _scanOperation = operation;
    return operation.whenComplete(() {
      if (identical(_scanOperation, operation)) _scanOperation = null;
    });
  }

  Future<void> refreshAfterInvalidation() async {
    if (audioDevicesLoading) {
      refreshQueued = true;
      final completion = queuedAudioRefreshCompletion ??= Completer<void>();
      await completion.future;
      return;
    }
    await refreshAudioDevices();
  }

  Future<void> _refreshAudioDevices() async {
    final ticket = scope.capture();
    if (isDisposed || !ticket.isActive) return;
    final revision = deviceRevision;
    audioDevicesLoading = true;
    audioDeviceScanFailed = false;
    audioDeviceScanStatus = AudioDeviceScanStatus.initializing;
    audioDeviceScanFailure = null;
    audioSettingsError = null;
    notifyListeners();
    try {
      final devices = await loader();
      if (!isDisposed && ticket.isActive && revision == deviceRevision) {
        audioDeviceScanFailed = false;
        audioDeviceScanStatus = AudioDeviceScanStatus.ready;
        audioDeviceScanFailure = null;
        applyAudioDevices(devices);
      }
    } catch (cause) {
      if (!isDisposed && ticket.isActive && revision == deviceRevision) {
        audioDeviceScanFailed = true;
        audioDeviceScanStatus = AudioDeviceScanStatus.error;
        audioDeviceScanFailure = classifyAudioDeviceFailure(cause);
        audioSettingsError = audioDeviceFailureMessage(audioDeviceScanFailure!);
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
            await _refreshAudioDevices();
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
  void cancelOperations() {
    _scanOperation = null;
    super.cancelOperations();
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
    unawaited(refreshAfterInvalidation());
  }
}
