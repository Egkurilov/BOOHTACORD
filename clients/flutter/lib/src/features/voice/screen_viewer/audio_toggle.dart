typedef ScreenAudioVolumeSetter = Future<void> Function(int percent);
typedef ScreenAudioMuteSetter = Future<void> Function(bool muted);

/// Matches the web client's selected-stream audio toggle behavior.
Future<void> toggleScreenAudioWithCallbacks({
  required int? volume,
  required bool muted,
  required ScreenAudioVolumeSetter setVolume,
  required ScreenAudioMuteSetter setMuted,
}) async {
  if (volume == 0) {
    await setVolume(100);
    if (muted) await setMuted(false);
    return;
  }
  await setMuted(!muted);
}
