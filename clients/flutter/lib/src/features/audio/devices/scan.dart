import 'dart:async';

import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/android_audio_devices.dart';
import 'state.dart';
import 'platform.dart';

AudioDeviceScanFailure classifyAudioDeviceFailure(
  Object cause, {
  bool bootstrap = false,
}) {
  if (cause is PlatformException) {
    final code = cause.code.toLowerCase();
    if (code.contains('restricted')) {
      return AudioDeviceScanFailure.permissionRestricted;
    }
    if (code.contains('permission') ||
        code.contains('denied') ||
        code.contains('notauthorized')) {
      return AudioDeviceScanFailure.permissionDenied;
    }
    if (code.contains('init') ||
        code.contains('factory') ||
        code.contains('webrtc')) {
      return AudioDeviceScanFailure.initializationFailed;
    }
  }
  if (cause is TimeoutException || (bootstrap && cause is StateError)) {
    return AudioDeviceScanFailure.initializationFailed;
  }
  return AudioDeviceScanFailure.enumerationFailed;
}

String audioDeviceFailureMessage(AudioDeviceScanFailure failure) {
  switch (failure) {
    case AudioDeviceScanFailure.permissionDenied:
      return 'macOS запретил доступ к аудиоустройствам. Разрешите доступ к микрофону в настройках системы и повторите попытку.';
    case AudioDeviceScanFailure.permissionRestricted:
      return 'Доступ к аудиоустройствам ограничен системой. Проверьте настройки конфиденциальности macOS.';
    case AudioDeviceScanFailure.initializationFailed:
      return 'Не удалось инициализировать аудиосистему. Повторите попытку или перезапустите приложение.';
    case AudioDeviceScanFailure.enumerationFailed:
      return 'Не удалось получить список аудиоустройств. Повторите попытку.';
  }
}

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
