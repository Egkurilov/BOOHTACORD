import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/src/utils/voice_reconnect_policy.dart';

void main() {
  test('uses the web retry base delays and six-attempt limit', () {
    expect(voiceReconnectAttemptLimit, 6);
    expect(
      List<int>.generate(
        voiceReconnectAttemptLimit,
        (retryCount) => voiceReconnectDelayInMs(
          retryCount,
          randomValue: 0.5,
        ),
      ),
      [250, 500, 1000, 2000, 4000, 4000],
    );
  });

  test('applies the same inclusive lower and exclusive upper jitter range', () {
    expect(voiceReconnectDelayInMs(0, randomValue: 0), 200);
    expect(voiceReconnectDelayInMs(5, randomValue: 0), 3200);
    expect(voiceReconnectDelayInMs(0, randomValue: 0.999999), 299);
    expect(voiceReconnectDelayInMs(5, randomValue: 0.999999), 4799);
  });

  test('rejects retries outside the web policy budget', () {
    expect(
      () => voiceReconnectDelayInMs(-1, randomValue: 0.5),
      throwsRangeError,
    );
    expect(
      () => voiceReconnectDelayInMs(voiceReconnectAttemptLimit, randomValue: 0.5),
      throwsRangeError,
    );
    expect(
      () => voiceReconnectDelayInMs(0, randomValue: 1),
      throwsRangeError,
    );
  });
}
