import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'scan.dart';
import 'state.dart';

mixin AudioDeviceBootstrap on AudioDeviceState, AudioDeviceScan {
  void watch();

  Future<void>? _bootstrapOperation;
  Object? _nativeBootstrapFailure;
  bool _nativeBootstrapPending = false;
  int _bootstrapRevision = 0;
  bool get nativeAudioBootstrapPending => _nativeBootstrapPending;

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

  @override
  Future<void> refreshAudioDevices() async {
    await super.refreshAudioDevices();
    final cause = _nativeBootstrapFailure;
    if (cause == null || isDisposed) return;
    final failure = classifyAudioDeviceFailure(cause, bootstrap: true);
    if (audioDeviceScanStatus != AudioDeviceScanStatus.ready ||
        !_hasConcreteEndpoint(audioInputDevices.followedBy(audioOutputDevices))) {
      _publishBootstrapFailure(failure);
      notifyListeners();
      return;
    }
    audioDeviceWarning = audioDeviceFailureMessage(failure);
    notifyListeners();
  }

  bool acceptAudioDeviceChange(List<MediaDevice> devices) {
    final cause = _nativeBootstrapFailure;
    if (cause != null && !_hasConcreteEndpoint(devices)) {
      _publishBootstrapFailure(
        classifyAudioDeviceFailure(cause, bootstrap: true),
      );
      return false;
    }
    _nativeBootstrapFailure = null;
    audioDeviceScanFailed = false;
    audioDeviceScanStatus = AudioDeviceScanStatus.ready;
    audioDeviceScanFailure = null;
    audioSettingsError = null;
    audioDeviceWarning = null;
    return true;
  }

  Future<void> _bootstrapAudioDevices() async {
    final ticket = scope.capture();
    final revision = ++_bootstrapRevision;
    final previousFailure = _nativeBootstrapFailure;
    _nativeBootstrapFailure = null;
    _nativeBootstrapPending = true;
    audioDeviceScanStatus = AudioDeviceScanStatus.initializing;
    audioDeviceScanFailure = null;
    audioDeviceScanFailed = false;
    if (previousFailure != null) {
      audioDeviceWarning = null;
      audioSettingsError = null;
    }
    notifyListeners();

    Object? bootstrapFailure;
    try {
      final initializeNative = nativeBootstrap;
      if (initializeNative != null) {
        await initializeNative().timeout(const Duration(seconds: 5));
      }
    } catch (cause) {
      bootstrapFailure = cause;
    }
    if (isDisposed || !ticket.isActive || revision != _bootstrapRevision) return;
    _nativeBootstrapPending = false;
    _nativeBootstrapFailure = bootstrapFailure;
    watch();
    await refreshAudioDevices();
  }

  void _publishBootstrapFailure(AudioDeviceScanFailure failure) {
    final message = audioDeviceFailureMessage(failure);
    audioDeviceScanFailed = true;
    audioDeviceScanStatus = AudioDeviceScanStatus.error;
    audioDeviceScanFailure = failure;
    audioDeviceWarning = null;
    audioSettingsError = message;
  }

  bool _hasConcreteEndpoint(Iterable<MediaDevice> devices) => devices.any(
    (device) =>
        (device.kind == 'audioinput' || device.kind == 'audiooutput') &&
        device.deviceId.isNotEmpty &&
        device.deviceId != 'default',
  );

  @override
  void cancelOperations() {
    super.cancelOperations();
    _bootstrapOperation = null;
    _bootstrapRevision++;
    _nativeBootstrapFailure = null;
    _nativeBootstrapPending = false;
  }
}
