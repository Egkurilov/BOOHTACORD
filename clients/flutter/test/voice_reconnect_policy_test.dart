import 'package:boohtacord_desktop/src/services/voice_reconnect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows the six web-policy retry attempts and rejects the seventh', () {
    expect([1, 2, 3, 4, 5, 6].every(shouldAllowVoiceReconnectAttempt), isTrue);
    expect(shouldAllowVoiceReconnectAttempt(7), isFalse);
    expect(shouldAllowVoiceReconnectAttempt(10), isFalse);
  });
}
