import 'package:livekit_client/livekit_client.dart';

import '../../../services/android_audio_devices.dart';

Future<List<MediaDevice>> enumerateAudioDevices() async {
  final devices = await Hardware.instance.enumerateDevices();
  final additional = await AndroidAudioDevices.enumerateAdditionalDevices();
  return mergeAudioDeviceLists(devices, additional);
}

List<MediaDevice> mergeAudioDeviceLists(
  List<MediaDevice> devices,
  List<MediaDevice> additional,
) {
  final knownIds = devices
      .map((device) => '${device.kind}:${device.deviceId}')
      .toSet();
  final allDevices = [
    ...devices,
    ...additional.where(
      (device) => !knownIds.contains('${device.kind}:${device.deviceId}'),
    ),
  ];
  if (AndroidAudioDevices.isAndroid &&
      !allDevices.any((device) => device.kind == 'audiooutput')) {
    // Android may expose its active system output only through the
    // communication route, while the plugin's enumeration is empty (for
    // example before API 31). Keep the OS default usable and truthfully
    // selectable instead of claiming that no speaker exists.
    allDevices.add(
      const MediaDevice(
        'default',
        'Системный динамик',
        'audiooutput',
        'android:default',
      ),
    );
  }
  return allDevices;
}
