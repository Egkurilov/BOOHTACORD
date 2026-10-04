import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
import '../../../services/voice_processing_platform.dart';
import 'state.dart';
part 'processing_runtime.dart';

mixin AudioDeviceProcessing on AudioDeviceState {
  void monitorNativeNoise() => _monitorNativeNoise();
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
      await applyMicrophoneControls(agc: next.autoGainControl);
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
        await applyMicrophoneControls(agc: previous.autoGainControl);
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
