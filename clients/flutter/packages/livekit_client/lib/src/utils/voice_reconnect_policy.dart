/// Web and Flutter use the same bounded exponential reconnect schedule.
///
/// [retryCount] is zero-based and identifies the retry that is about to be
/// scheduled. [randomValue] must be in [0, 1), matching the web policy's
/// `Math.random()` input.
const int voiceReconnectAttemptLimit = 6;
const int voiceReconnectBaseDelayMs = 250;
const int voiceReconnectMaxDelayMs = 4000;

int voiceReconnectDelayInMs(
  int retryCount, {
  required double randomValue,
}) {
  if (retryCount < 0 || retryCount >= voiceReconnectAttemptLimit) {
    throw RangeError.range(retryCount, 0, voiceReconnectAttemptLimit - 1);
  }
  if (randomValue < 0 || randomValue >= 1 || !randomValue.isFinite) {
    throw RangeError.range(randomValue, 0, 1, 'randomValue', 'must be < 1');
  }

  final baseDelay = (voiceReconnectBaseDelayMs * (1 << retryCount)).clamp(
    0,
    voiceReconnectMaxDelayMs,
  );
  return (baseDelay * (0.8 + randomValue * 0.4)).floor();
}
