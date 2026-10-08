import '../native_bindings.dart';

MediaDevice? workspaceAudioDeviceShownByDropdown(
  List<MediaDevice> devices,
  String? selectedId,
) =>
    devices.where((device) => device.deviceId == selectedId).firstOrNull ??
    devices.firstOrNull;
