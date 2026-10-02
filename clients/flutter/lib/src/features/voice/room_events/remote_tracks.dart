import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

extension VoiceEventsRemoteTracks on VoiceController {
  void bindRemoteTracks(
    Room room,
    EventsListener<RoomEvent> listener,
    bool Function() owns,
  ) {
    listener.on<TrackSubscribedEvent>((event) {
      if (!owns()) return;
      if (!identical(this.room, room)) return;
      if (event.publication.source == TrackSource.screenShareVideo &&
          event.track is RemoteVideoTrack) {
        final waiter = screenPreviewTrackWaiters[event.publication.sid];
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(event.track as RemoteVideoTrack);
        }
      }
      if (event.track is RemoteAudioTrack) {
        if (deafened) unawaited(event.publication.disable());
        unawaited(
          applySavedAudioVolume(event.participant, event.publication.source),
        );
      }
    });
    void refreshVoiceNavigation() {
      if (!owns()) return;
      if (!identical(this.room, room)) return;
      observeVoiceStreamStarts(room);
      notifyListeners();
    }

    listener.on<ParticipantConnectedEvent>((_) => refreshVoiceNavigation());
    listener.on<ParticipantDisconnectedEvent>((event) {
      if (!owns()) return;
      screenThumbnails.remove(event.participant.identity);
      final endedTrackIds = screenThumbnailRemoteTrackIds.entries
          .where((entry) => entry.value == event.participant.identity)
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final trackId in endedTrackIds) {
        final waiter = screenPreviewTrackWaiters[trackId];
        if (waiter != null && !waiter.isCompleted) waiter.complete(null);
        screenThumbnailRemoteTrackIds.remove(trackId);
      }
      if (selectedRemoteScreenViewerIdentity == event.participant.identity) {
        selectedRemoteScreenViewerIdentity = null;
      }
      refreshVoiceNavigation();
    });
    listener.on<ActiveSpeakersChangedEvent>((_) => refreshVoiceNavigation());
    listener.on<TrackPublishedEvent>((event) {
      if (!owns()) return;
      if (identical(this.room, room)) {
        if (event.publication.source == TrackSource.microphone) {
          unawaited(setRemoteTrackSubscription(event.publication, true));
        } else if (event.publication.source == TrackSource.screenShareVideo) {
          queueRemoteScreenThumbnail(
            room,
            event.participant,
            event.publication,
          );
        }
      }
      refreshVoiceNavigation();
    });
    listener.on<TrackUnpublishedEvent>((event) {
      if (!owns()) return;
      if (event.publication.source == TrackSource.screenShareVideo) {
        screenThumbnails.remove(event.participant.identity);
        screenThumbnailRemoteTrackIds.remove(event.publication.sid);
        final waiter = screenPreviewTrackWaiters[event.publication.sid];
        if (waiter != null && !waiter.isCompleted) waiter.complete(null);
        if (selectedRemoteScreenViewerIdentity == event.participant.identity) {
          unawaited(selectRemoteScreenForViewing(null));
        }
      }
      refreshVoiceNavigation();
    });
    listener.on<TrackMutedEvent>((_) => refreshVoiceNavigation());
    listener.on<TrackUnmutedEvent>((_) => refreshVoiceNavigation());
    listener.on<TrackSubscribedEvent>((_) => refreshVoiceNavigation());
    listener.on<TrackUnsubscribedEvent>((event) {
      if (!owns()) return;
      if (event.publication.source == TrackSource.screenShareVideo) {
        screenThumbnailRemoteTrackIds.remove(event.publication.sid);
        final waiter = screenPreviewTrackWaiters[event.publication.sid];
        if (waiter != null && !waiter.isCompleted) waiter.complete(null);
      }
      refreshVoiceNavigation();
    });
  }
}
