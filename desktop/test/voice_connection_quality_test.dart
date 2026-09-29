import 'package:boohtacord_desktop/src/services/voice_connection_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' show ConnectionQuality;

void main() {
  test('maps LiveKit quality to concise localized labels', () {
    expect(voiceConnectionQualityLabel(ConnectionQuality.excellent), 'Отличное');
    expect(voiceConnectionQualityLabel(ConnectionQuality.good), 'Хорошее');
    expect(voiceConnectionQualityLabel(ConnectionQuality.poor), 'Низкое');
    expect(voiceConnectionQualityLabel(ConnectionQuality.lost), 'Потеряно');
    expect(voiceConnectionQualityLabel(ConnectionQuality.unknown), 'Нет данных');
  });

  test('converts only finite bounded RTT seconds to milliseconds', () {
    expect(voiceRttMilliseconds(0.0424), 42);
    expect(voiceRttMilliseconds(0), 0);
    expect(voiceRttMilliseconds(null), isNull);
    expect(voiceRttMilliseconds(-0.1), isNull);
    expect(voiceRttMilliseconds(double.nan), isNull);
    expect(voiceRttMilliseconds(61), isNull);
  });
}
