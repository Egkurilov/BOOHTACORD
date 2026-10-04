part of 'processing.dart';
extension AudioProcessingRuntime on AudioDeviceState {
  Future<void> _applyTrackProcessing(
    LocalAudioTrack track,
    AudioProcessingPreferences next,
  ) => applyVoiceProcessingForPlatform(
    platform: defaultTargetPlatform,
    current: track.currentOptions,
    next: next,
    recapture: (options) async {
      await track.restartTrack(options);
      if (microphoneMutedIntent || track.muted) await track.disable();
    },
    // ignore: experimental_member_use
    updateRuntime: track.setAudioProcessingOptions,
  );
  void _monitorNativeNoise() {
    nativeNoise.monitor((reason) async {
      final targetRoom = room;
      final track = targetRoom?.localParticipant
          ?.getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is! LocalAudioTrack || isDisposed) return;
      final recovery = ++nativeRecoveryRevision;
      Future<void> restoreBrowser() async {
        await track.mute(stopOnMute: false);
        await nativeNoise.reset();
        await nativeNoise.useFallback(reason, captureApplied: false);
        final browser = audioProcessing.copyWith(
          noiseSuppressionMode: NoiseSuppressionMode.browser,
        );
        await _applyTrackProcessing(track, browser);
        if (recovery != nativeRecoveryRevision ||
            !identical(targetRoom, room) ||
            isDisposed) {
          return;
        }
        captureNoiseOverride = NoiseSuppressionMode.browser;
        nativeNoise.confirmFallback(reason);
        if (!microphoneMutedIntent) await track.unmute(stopOnMute: false);
      }

      try {
        await restoreBrowser().timeout(const Duration(milliseconds: 850));
      } catch (_) {
        nativeRecoveryRevision++;
        microphoneMutedIntent = true;
        unawaited(track.mute(stopOnMute: false).catchError((_) => false));
        nativeNoise.failMuted('browser-recovery-failed');
        audioSettingsError =
            'Не удалось восстановить микрофон. Отправка звука выключена.';
      }
      notifyListeners();
    });
  }

}
