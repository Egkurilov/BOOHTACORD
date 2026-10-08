import 'dart:async';

import 'package:flutter/services.dart';

import 'state.dart';

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
