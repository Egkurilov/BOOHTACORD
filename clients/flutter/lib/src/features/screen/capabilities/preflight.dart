import 'package:flutter/foundation.dart';

/// Source implementation support, not a hardware acceptance result. No capture
/// or permission request occurs here; returned tracks remain authoritative.
class ScreenPreflight {
  const ScreenPreflight({
    required this.captureConfigured,
    required this.videoLabel,
    required this.audioLabel,
    required this.viewerLabel,
  });
  final bool captureConfigured;
  final String videoLabel, audioLabel, viewerLabel;
  static ScreenPreflight detect({
    required TargetPlatform platform,
    bool web = false,
    bool selecting = false,
    bool sourceAvailable = false,
    bool sourceError = false,
  }) {
    final supported =
        !web &&
        {
          TargetPlatform.linux,
          TargetPlatform.windows,
          TargetPlatform.macOS,
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(platform);
    final video = !supported
        ? 'Захват экрана недоступен на этой платформе.'
        : platform == TargetPlatform.iOS
        ? 'Видео: только содержимое BOOHTACORD; разрешение проверяется при запуске.'
        : selecting && sourceError
        ? 'Видео: список источников недоступен. Повторите загрузку.'
        : selecting && !sourceAvailable
        ? 'Видео: проверяем доступные экраны и окна.'
        : selecting
        ? 'Видео: доступные экраны и окна; системное разрешение проверяется при запуске.'
        : 'Видео: системный выбор источника и разрешение при запуске.';
    return ScreenPreflight(
      captureConfigured: supported && !sourceError,
      videoLabel: video,
      audioLabel: 'Звук экрана не публикуется native-клиентом. Звук игры не передаётся.',
      viewerLabel:
          'Просмотр чужой демонстрации и голосовой канал остаются доступны.',
    );
  }
}
