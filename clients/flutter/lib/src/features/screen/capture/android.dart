import 'package:flutter/foundation.dart';

import 'cancelled.dart';

import 'package:flutter/services.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

Future<void> prepareAndroidScreenShare(bool Function() active) async {
  if (defaultTargetPlatform != TargetPlatform.android || !active()) return;
  final permitted = await rtc.Helper.requestCapturePermission();
  if (!active()) return;
  if (!permitted) throw const ScreenCaptureCancelled();
  final initialized = await FlutterBackground.initialize(
    androidConfig: const FlutterBackgroundAndroidConfig(
      notificationTitle: 'Демонстрация экрана',
      notificationText: 'Экран передаётся участникам голосового канала',
      shouldRequestBatteryOptimizationsOff: false,
    ),
  );
  if (!active()) return;
  if (!initialized || !await FlutterBackground.enableBackgroundExecution()) {
    throw StateError('Не удалось включить фоновую передачу экрана.');
  }
  if (!active()) return;
  final foregroundStarted = await const MethodChannel('boohtacord/screen_share')
      .invokeMethod<bool>('awaitForegroundService', {'timeoutMs': 3000});
  if (!active()) return;
  if (foregroundStarted != true) {
    throw StateError(
      'Android не успел запустить foreground service для захвата экрана.',
    );
  }
}

Future<void> disableAndroidScreenShareBackground() async {
  if (defaultTargetPlatform != TargetPlatform.android ||
      !FlutterBackground.isBackgroundExecutionEnabled) {
    return;
  }
  try {
    await FlutterBackground.disableBackgroundExecution();
  } catch (_) {}
}
