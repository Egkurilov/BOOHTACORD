import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
import '../lifecycle/controller.dart';
import '../background_microphone/admission.dart';

extension VoiceMicrophoneCapture on VoiceController {
  Future<bool> applyMicrophoneMuted(bool muted) {
    final ticket = scope.capture();
    final revision = operationRevision;
    final request = ++microphoneRevision;
    final targetRoom = room;
    final participant = targetRoom?.localParticipant;
    bool current() => active(ticket, revision) && identical(room, targetRoom);
    audio.microphoneMutedIntent = muted;
    audio.microphoneVad = audioActivationMode == AudioActivationMode.vad;
    if (muted) {
      audio.nativeMicrophone.pause();
      final track = participant
          ?.getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is LocalAudioTrack) unawaited(track.mute(stopOnMute: false));
      unawaited(audio.nativeNoise.reset());
    }
    final operation = audio.nativeNoise.run(() async {
      if (!current()) return false;
      try {
        if (!muted) { await preflightBackgroundMicrophone(); await audio.prepareNoiseForCapture(); await audio.applyMicrophoneControls(); }
        if (!current()) return false;
        await audio.nativeNoise.reset();
        await participant?.setMicrophoneEnabled(
          !audio.microphoneMutedIntent,
          audioCaptureOptions: audio.captureOptions,
        );
        if (current()) await promoteBackgroundMicrophone(participant);
        if (!current()) {
          await microphoneForeground.stop();
          if (!muted) {
            try {
              await participant?.setMicrophoneEnabled(false);
            } catch (_) {}
          }
          return false;
        }
        if (!muted) {
          if (audio.captureNoiseOverride == NoiseSuppressionMode.browser &&
              audio.audioProcessing.noiseSuppressionMode ==
                  NoiseSuppressionMode.rnnoise) {
            audio.nativeNoise.confirmFallback(
              audio.nativeNoise.state.failureReason ?? 'unsupported',
              unsupported: true,
            );
          }
          audio.monitorNativeNoise();
          audio.nativeMicrophone.monitor();
        }
        if (request == microphoneRevision) {
          microphoneMuted = muted;
          if (!muted) {
            audio.refreshAfterMicrophoneCapture();
            microphoneUnavailable = false;
          }
        }
        return true;
      } catch (cause) {
        await microphoneForeground.stop();
        if (current() && request == microphoneRevision) {
          microphoneMuted = true;
          if (!muted) microphoneUnavailable = true;
          audioActivationError =
              'Не удалось изменить микрофон: ${formatError(cause)}';
        }
        return false;
      }
    });
    microphoneTail = operation.then((_) {});
    return operation;
  }

  Future<void> toggleMicrophone() async {
    final ticket = scope.capture();
    final revision = operationRevision;
    if (!active(ticket, revision) ||
        room == null ||
        deafened ||
        audioActivationMode == AudioActivationMode.ptt) {
      return;
    }
    final muted = !microphoneMuted;
    microphoneMuted = muted;
    final success = await applyMicrophoneMuted(muted);
    if (!active(ticket, revision)) return;
    if (!success) {
      microphoneMuted = true;
      microphoneUnavailable = true;
      error = audioActivationError;
    } else if (!muted) {
      error = null;
      listenerOnly = false;
      if (voicePhase == VoicePhase.listener) voicePhase = VoicePhase.connected;
    }
    notifyListeners();
  }
}
