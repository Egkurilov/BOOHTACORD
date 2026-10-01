import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'state.dart';
import 'scan.dart';
import 'inventory.dart';
import 'selection.dart';
import 'processing.dart';

class AudioDeviceController extends AudioDeviceState
    with
        AudioDeviceScan,
        AudioDeviceInventory,
        AudioDeviceSelection,
        AudioDeviceProcessing {
  AudioDeviceController({required super.readRoom, super.loader, super.changes});

  void watch() {
    if (isDisposed) return;
    subscription ??= (changes ?? Hardware.instance.onDeviceChange.stream)
        .listen((devices) {
          final revision = ++deviceRevision;
          audioDeviceScanFailed = false;
          applyAudioDevices(devices);
          notifyListeners();
          unawaited(applyAndroidAdditions(devices, revision));
        });
  }
}
