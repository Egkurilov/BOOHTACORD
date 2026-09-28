import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' show MediaDevice;

/// Android USB routes are not exposed by flutter_webrtc's current device list.
/// Keep the OS-specific additions behind a small channel and let WebRTC retain
/// ownership of microphone capture and all routes it already supports.
class AndroidAudioDevices {
  AndroidAudioDevices._();

  static const _channel = MethodChannel('boohtacord/audio_devices');
  static const outputRoutePrefix = 'android-usb-route:';

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<List<MediaDevice>> enumerateAdditionalDevices() async {
    if (!isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<Object?>('enumerateUsb');
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

  static Future<bool> selectUsbOutput(String deviceId) async {
    if (!isAndroid || !isUsbOutput(deviceId)) return false;
    return await _channel.invokeMethod<bool>('selectUsbOutput', {
          'deviceId': deviceId.substring(outputRoutePrefix.length),
        }) ??
        false;
  }

  static Future<void> clearUsbOutput() async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('clearUsbOutput');
  }
}
