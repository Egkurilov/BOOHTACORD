import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;

/// Android communication outputs and some USB inputs are not exposed by
/// flutter_webrtc's current device list. Keep OS-specific additions behind a
/// small channel and let WebRTC retain ownership of microphone capture.
class AndroidAudioDevices {
  AndroidAudioDevices._();

  static const _channel = MethodChannel('boohtacord/audio_devices');
  // Keep the USB prefix stable because it may already be stored in preferences.
  static const outputRoutePrefix = 'android-usb-route:';
  static const communicationOutputRoutePrefix = 'android-communication-route:';

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<List<MediaDevice>> enumerateAdditionalDevices() async {
    if (!isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<Object?>(
        'enumerateAudioDevices',
      );
      return [
        for (final value in raw ?? const [])
          if (value case final Map<Object?, Object?> device)
            if (device['deviceId'] is String &&
                device['kind'] is String &&
                device['label'] is String)
              MediaDevice(
                device['deviceId']! as String,
                device['label']! as String,
                device['kind']! as String,
                device['groupId'] as String?,
              ),
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static bool isUsbOutput(String? deviceId) =>
      deviceId?.startsWith(outputRoutePrefix) ?? false;

  static bool isNativeOutputRoute(String? deviceId) =>
      isUsbOutput(deviceId) ||
      (deviceId?.startsWith(communicationOutputRoutePrefix) ?? false);

  static Future<bool> selectNativeOutput(String deviceId) async {
    if (!isAndroid || !isNativeOutputRoute(deviceId)) return false;
    final routeId = isUsbOutput(deviceId)
        ? deviceId.substring(outputRoutePrefix.length)
        : deviceId.substring(communicationOutputRoutePrefix.length);
    return await _channel.invokeMethod<bool>('selectCommunicationOutput', {
          'deviceId': routeId,
        }) ??
        false;
  }

  static Future<void> clearNativeOutput() async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('clearCommunicationOutput');
  }

  /// Resolves a WebRTC input ID to the AudioRecord device ID used by `record`.
  /// WebRTC names built-in mics by address (for example `microphone-bottom`),
  /// while `record` expects Android's numeric AudioDeviceInfo ID.
  static Future<String?> recorderInputDeviceId(String? deviceId) async {
    if (!isAndroid || deviceId == null || deviceId.isEmpty) return null;
    try {
      return await _channel.invokeMethod<String>('mapRecorderInputDevice', {
        'deviceId': deviceId,
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
