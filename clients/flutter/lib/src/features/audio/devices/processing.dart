import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
import '../../../services/voice_processing_platform.dart';
import 'state.dart';

mixin AudioDeviceProcessing on AudioDeviceState {
  Future<void> setAudioProcessing(AudioProcessingPreferences next) async {
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
    audioProcessing = next;
    audioSettingsError = null;
    try {
      final track = room?.localParticipant
          ?.getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is LocalAudioTrack) {
        await applyVoiceProcessingForPlatform(
          platform: defaultTargetPlatform,
          current: track.currentOptions,
          next: next,
          recapture: track.restartTrack,
          // ignore: experimental_member_use
          updateRuntime: track.setAudioProcessingOptions,
        );
        if (!current()) return;
      }
      await settings?.setProcessing(next);
      if (!current()) return;
    } catch (cause) {
      if (!current()) return;
      audioProcessing = previous;
      audioSettingsError =
          'Не удалось применить обработку микрофона: ${cause.runtimeType}.';
    }
    if (current()) notifyListeners();
  }
}
