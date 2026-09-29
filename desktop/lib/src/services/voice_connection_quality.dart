import 'package:livekit_client/livekit_client.dart' show ConnectionQuality;

String voiceConnectionQualityLabel(ConnectionQuality quality) => switch (
  quality
) {
  ConnectionQuality.excellent => 'Отличное',
  ConnectionQuality.good => 'Хорошее',
  ConnectionQuality.poor => 'Низкое',
  ConnectionQuality.lost => 'Потеряно',
  ConnectionQuality.unknown => 'Нет данных',
};

int? voiceRttMilliseconds(num? seconds) {
  if (seconds == null || !seconds.isFinite || seconds < 0 || seconds > 60) {
    return null;
  }
  return (seconds * 1000).round();
}
