String mediaNumber(double? value, String unit) {
  if (value == null) return 'Нет данных';
  final number = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$number $unit';
}

String mediaPlatformLabel(String platform) => switch (platform) {
  'ios_web' => 'iPhone/iPad · браузер',
  'android_web' => 'Android · браузер',
  'desktop_web' => 'ПК · браузер',
  'android_native' => 'Android · приложение',
  'desktop_native' => 'ПК · приложение',
  'ios_native' => 'iPhone/iPad · приложение',
  'windows_native' => 'Windows · приложение',
  'macos_native' => 'macOS · приложение',
  _ => 'Неизвестная платформа',
};

String mediaStateLabel(String state) => switch (state) {
  'waiting_subscription' => 'Ожидает видеодорожку',
  'waiting_first_frame' => 'Ожидает первый кадр',
  'playing' => 'Воспроизводит',
  'stalled' => 'Кадры остановились',
  _ => 'Неизвестное состояние',
};

String mediaFrameSize(int? width, int? height) =>
    width == null || height == null ? 'Нет данных' : '$width × $height';
