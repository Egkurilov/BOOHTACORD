class ScreenMediaRollout {
  const ScreenMediaRollout({
    this.descriptor = const bool.fromEnvironment('BOOHTACORD_SCREEN_DESCRIPTOR_V1', defaultValue: true),
    this.jpegPreview = const bool.fromEnvironment('BOOHTACORD_SCREEN_PREVIEWS_V1', defaultValue: true),
    this.boundedSimulcast = const bool.fromEnvironment('BOOHTACORD_SCREEN_BOUNDED_SIMULCAST', defaultValue: false),
  });
  final bool descriptor, jpegPreview, boundedSimulcast;
}
