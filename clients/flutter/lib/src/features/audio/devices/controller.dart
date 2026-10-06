import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'state.dart';
import 'scan.dart';
import 'inventory.dart';
import 'selection.dart';
import 'processing.dart';
import 'microphone.dart';

class AudioDeviceController extends AudioDeviceState
    with
        AudioDeviceScan,
        AudioDeviceInventory,
        AudioDeviceSelection,
        AudioDeviceProcessing,
        AudioDeviceMicrophone {
  Future<void>? _bootstrapOperation;

  AudioDeviceController({
    required super.readRoom,
    super.readAccountId,
    super.loader,
    super.changes,
    super.nativeBootstrap,
    super.scope,
  }) {
    nativeNoise.addListener(notifyListeners);
    // Meter widgets subscribe directly; avoid rebuilding the workspace at 10 Hz.
  }

  /// Initializes the native audio module and publishes the first device list.
  ///
  /// This is deliberately single-flight: account restoration, opening the
  /// audio settings panel, and a reconnect may all request the same bootstrap
  /// concurrently. The existing join-time refresh remains a safe fallback.
  Future<void> bootstrap() {
    final pending = _bootstrapOperation;
    if (pending != null) return pending;
    final operation = _bootstrapAudioDevices();
    _bootstrapOperation = operation;
    return operation.whenComplete(() {
      if (identical(_bootstrapOperation, operation)) {
        _bootstrapOperation = null;
      }
    });
  }

  Future<void> _bootstrapAudioDevices() async {
    if (isDisposed) return;
    Object? bootstrapFailure;
    final initializeNative = nativeBootstrap;
    if (initializeNative != null) {
      try {
        await initializeNative().timeout(const Duration(seconds: 5));
      } catch (cause) {
        // Device discovery is useful even when native initialization is
        // unavailable (for example while macOS permissions are pending). Do
        // not make account restoration fail because of an audio subsystem.
        bootstrapFailure = cause;
      }
    }
    if (isDisposed || !scope.capture().isActive) return;
    watch();
    await refreshAudioDevices();
    if (bootstrapFailure == null || isDisposed || !scope.capture().isActive) {
      return;
    }
    audioDeviceWarning =
        'Не удалось инициализировать аудиосистему: ${bootstrapFailure.runtimeType}.';
    if (audioInputDevices.isEmpty && audioOutputDevices.isEmpty) {
      audioDeviceScanFailed = true;
      audioSettingsError = audioDeviceWarning;
    }
    notifyListeners();
  }

  @override
  void cancelOperations() {
    super.cancelOperations();
    // A native initialization cannot be cancelled, but a new account must
    // not await the previous account's in-flight bootstrap.
    _bootstrapOperation = null;
  }

  void watch() {
    if (isDisposed) return;
    subscription ??= (changes ?? Hardware.instance.onDeviceChange.stream)
        .listen((devices) {
          if (isDisposed || !scope.capture().isActive) return;
          final revision = ++deviceRevision;
          audioDeviceScanFailed = false;
          applyAudioDevices(devices);
          notifyListeners();
          unawaited(applyAndroidAdditions(devices, revision));
        });
  }
}
