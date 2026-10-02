import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../services/audio_preferences.dart';
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
        // ignore: experimental_member_use
        await track.setAudioProcessingOptions(
          // ignore: experimental_member_use
          AudioProcessingOptions(
            autoGainControl: next.autoGainControl,
            echoCancellation: next.echoCancellation,
            noiseSuppression: next.noiseSuppression,
            highPassFilter: false,
          ),
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
