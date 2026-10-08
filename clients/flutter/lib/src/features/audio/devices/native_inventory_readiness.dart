import 'package:livekit_client/livekit_client.dart';

import 'failure.dart';
import 'state.dart';

mixin AudioDeviceNativeInventoryReadiness on AudioDeviceState {
  bool acceptNativeInventory(
    List<MediaDevice> devices, {
    Object? bootstrapFailure,
  }) {
    if (bootstrapFailure != null && !hasConcreteNativeEndpoint(devices)) {
      publishNativeBootstrapFailure(
        classifyAudioDeviceFailure(bootstrapFailure, bootstrap: true),
      );
      return false;
    }
    if (isAwaitingNativeInventory(devices)) {
      publishAwaitingNativeInventory();
      return false;
    }
    audioDeviceScanFailed = false;
    audioDeviceScanStatus = AudioDeviceScanStatus.ready;
    audioDeviceScanFailure = null;
    audioSettingsError = null;
    audioDeviceWarning = null;
    return true;
  }

  void publishNativeBootstrapFailure(AudioDeviceScanFailure failure) {
    audioDeviceScanFailed = true;
    audioDeviceScanStatus = AudioDeviceScanStatus.error;
    audioDeviceScanFailure = failure;
    audioDeviceWarning = null;
    audioSettingsError = audioDeviceFailureMessage(failure);
  }

  void publishAwaitingNativeInventory() {
    audioDeviceScanFailed = false;
    audioDeviceScanStatus = AudioDeviceScanStatus.initializing;
    audioDeviceScanFailure = null;
    audioSettingsError = null;
    audioDeviceWarning = null;
  }

  bool isAwaitingNativeInventory(Iterable<MediaDevice> devices) {
    if (nativeBootstrap == null) return false;
    final endpoints = devices
        .where(
          (device) =>
              device.kind == 'audioinput' || device.kind == 'audiooutput',
        )
        .toList(growable: false);
    return endpoints.isNotEmpty && !hasConcreteNativeEndpoint(endpoints);
  }

  bool hasConcreteNativeEndpoint(Iterable<MediaDevice> devices) => devices.any(
    (device) =>
        (device.kind == 'audioinput' || device.kind == 'audiooutput') &&
        device.deviceId.isNotEmpty &&
        device.deviceId != 'default',
  );
}
