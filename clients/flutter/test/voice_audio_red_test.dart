import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/participant/audio_publication/features.dart';
void main() {
  test('RED option follows Web semantics and encryption disables it', () {
    expect(disableAudioRed(const AudioPublishOptions(red: true), encrypted: false), isFalse);
    expect(disableAudioRed(const AudioPublishOptions(red: false), encrypted: false), isTrue);
    expect(disableAudioRed(const AudioPublishOptions(), encrypted: false), isFalse);
    expect(disableAudioRed(const AudioPublishOptions(red: true), encrypted: true), isTrue);
  });
}
