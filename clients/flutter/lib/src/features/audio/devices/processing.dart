import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
import '../../../services/voice_processing_platform.dart';
import 'state.dart';

mixin AudioDeviceProcessing on AudioDeviceState {
  Future<void> setAudioProcessing(AudioProcessingPreferences next) {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    return nativeNoise.run(() async {
      if (!ticket.isActive ||
          !identical(settings, preferences) ||
          !identical(targetRoom, room) ||
          isDisposed) {
        return;
      }
      await _setAudioProcessing(next);
    });
  }

  Future<AudioProcessingPreferences> prepareNoiseForCapture() async {
    final mode = await nativeNoise.prepare(
      audioProcessing.noiseSuppressionMode,
    );
    captureNoiseOverride = mode;
    if (mode != audioProcessing.noiseSuppressionMode) {
      await nativeNoise.useFallback(
        nativeNoise.state.failureReason ?? 'unsupported',
        unsupported: true,
        captureApplied: false,
      );
    }
    return audioProcessing.copyWith(noiseSuppressionMode: mode);
  }

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
  void monitorNativeNoise() {
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

  Future<void> _setAudioProcessing(AudioProcessingPreferences next) async {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    bool current() =>
        !isDisposed &&
        ticket.isActive &&
        identical(settings, preferences) &&
        identical(targetRoom, room);
    if (!current()) return;
    final previous = audioProcessing;
    final previousOverride = captureNoiseOverride;
    audioSettingsError = null;
    final track = targetRoom?.localParticipant
        ?.getTrackPublicationBySource(TrackSource.microphone)
        ?.track;
    try {
      if (targetRoom == null) {
        await settings?.setProcessing(next);
        if (current()) audioProcessing = next;
        if (current()) notifyListeners();
        return;
      }
      if (track is LocalAudioTrack) await track.mute(stopOnMute: false);
      await nativeNoise.reset();
      final mode = await nativeNoise.prepare(next.noiseSuppressionMode);
      if (!current()) return;
      final effective = next.copyWith(noiseSuppressionMode: mode);
      if (track is LocalAudioTrack) {
        await _applyTrackProcessing(track, effective);
      }
      if (!current()) return;
      if (mode != next.noiseSuppressionMode) {
        await nativeNoise.useFallback(
          nativeNoise.state.failureReason ?? 'unsupported',
          unsupported: true,
        );
      }
      audioProcessing = next;
      captureNoiseOverride = mode;
      await settings?.setProcessing(next);
      if (!current()) return;
      if (track is LocalAudioTrack && !microphoneMutedIntent) {
        await track.unmute(stopOnMute: false);
      }
      if (track is LocalAudioTrack) monitorNativeNoise();
    } catch (cause) {
      if (!current()) return;
      audioProcessing = previous;
      captureNoiseOverride = previousOverride;
      try {
        await nativeNoise.prepare(previous.noiseSuppressionMode);
        if (track is LocalAudioTrack) {
          await _applyTrackProcessing(
            track,
            previous.copyWith(noiseSuppressionMode: previousOverride),
          );
          if (!microphoneMutedIntent) await track.unmute(stopOnMute: false);
        }
      } catch (_) {
        microphoneMutedIntent = true;
        if (track is LocalAudioTrack) await track.mute(stopOnMute: false);
        nativeNoise.failMuted('rollback-failed');
      }
      audioSettingsError =
          'Не удалось применить обработку микрофона: ${cause.runtimeType}.';
    }
    if (current()) notifyListeners();
  }
}
