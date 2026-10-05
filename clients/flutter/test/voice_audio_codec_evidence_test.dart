import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/audio_diagnostics/codec.dart';
void main() {
  test('Opus codec stats cannot prove RED disabled', () {
    final codec = audioCodec({'codecId': 'opus'}, [
      {'id': 'opus', 'type': 'codec', 'mimeType': 'audio/opus', 'clockRate': 48000, 'channels': 2},
    ]);
    expect(codec['codec'], 'opus');
    expect(codec['red'], isNull);
  });
}
