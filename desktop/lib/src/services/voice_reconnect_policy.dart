const voiceReconnectAttemptLimit = 6;

/// LiveKit's Flutter SDK reports the next reconnect attempt as a 1-based value.
/// The web client's BoundedVoiceReconnectPolicy permits retry counts 0–5,
/// which is six attempts total; the seventh scheduled attempt must be stopped.
bool shouldAllowVoiceReconnectAttempt(int attempt) =>
    attempt >= 1 && attempt <= voiceReconnectAttemptLimit;
