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
  AudioDeviceController({
    required super.readRoom,
    super.readAccountId,
    super.loader,
    super.changes,
    super.scope,
  }) {
    nativeNoise.addListener(notifyListeners);
    // Meter widgets subscribe directly; avoid rebuilding the workspace at 10 Hz.
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
