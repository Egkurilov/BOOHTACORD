import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_share_diagnostics.dart';
import '../lifecycle/controller.dart';
import '../screen_preview/capture_policy.dart';
import '../screen_viewer/audio_publication.dart';

extension VoiceEventsRemoteTracks on VoiceController {
  void bindRemoteTracks(
    Room room,
    EventsListener<RoomEvent> listener,
    bool Function() owns,
  ) {
    void logRemoteState(ScreenShareDiagnosticEvent event) {
      final counts = screenShareRemoteCounts(room);
      logScreenShareDiagnostic(
        event,
        platform: defaultTargetPlatform,
        remoteParticipants: counts?.participants,
        remoteScreenPublications: counts?.publications,
      );
    }

    listener.on<TrackSubscribedEvent>((event) {
      if (!owns()) return;
      if (!identical(this.room, room)) return;
      if (event.publication.source == TrackSource.screenShareVideo &&
          event.track is RemoteVideoTrack) {
        logRemoteState(ScreenShareDiagnosticEvent.remoteTrackSubscribed);
        final waiter = screenPreviewTrackWaiters[event.publication.sid];
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(event.track as RemoteVideoTrack);
        }
        unawaited(
          captureSelectedRemoteScreenThumbnail(
            temporaryPreview: screenThumbnailRemoteTrackIds.containsKey(
              event.publication.sid,
            ),
            capture: () => captureRemoteThumbnail(
              room,
              event.participant,
              event.publication,
              event.track as RemoteVideoTrack,
            ),
            source: event.publication.source,
            isRemoteVideoTrack: event.track is RemoteVideoTrack,
            participantIdentity: event.participant.identity,
            selectedIdentity: selectedRemoteScreenViewerIdentity,
          ),
        );
      }
      if (event.track is RemoteAudioTrack) {
        if (deafened) unawaited(event.publication.disable());
        final source =
            isScreenShareAudioPublication(event.participant, event.publication)
            ? TrackSource.screenShareAudio
            : event.publication.source;
        unawaited(applySavedAudioVolume(event.participant, source));
      }
    });
    void refreshVoiceNavigation() {
      if (!owns()) return;
      if (!identical(this.room, room)) return;
      observeVoiceStreamStarts(room);
      notifyListeners();
    }

    listener.on<ParticipantConnectedEvent>((_) {
      logRemoteState(ScreenShareDiagnosticEvent.remoteParticipantConnected);
      refreshVoiceNavigation();
    });
    listener.on<ParticipantDisconnectedEvent>((event) {
      if (!owns()) return;
      logRemoteState(ScreenShareDiagnosticEvent.remoteParticipantDisconnected);
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
          logRemoteState(ScreenShareDiagnosticEvent.remoteTrackPublished);
          queueRemoteScreenThumbnail(
            room,
            event.participant,
            event.publication,
          );
          if (event.participant.identity ==
              selectedRemoteScreenViewerIdentity) {
            subscribeRemoteScreenForViewing(room, event.participant.identity);
          }
        } else if (event.participant.identity ==
                selectedRemoteScreenViewerIdentity &&
            isScreenShareAudioPublication(
              event.participant,
              event.publication,
            )) {
          unawaited(setRemoteTrackSubscription(event.publication, true));
        }
      }
      refreshVoiceNavigation();
    });
    listener.on<TrackUnpublishedEvent>((event) {
      if (!owns()) return;
      if (event.publication.source == TrackSource.screenShareVideo) {
        logRemoteState(ScreenShareDiagnosticEvent.remoteTrackUnpublished);
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
        logRemoteState(ScreenShareDiagnosticEvent.remoteTrackUnsubscribed);
        screenThumbnailRemoteTrackIds.remove(event.publication.sid);
        final waiter = screenPreviewTrackWaiters[event.publication.sid];
        if (waiter != null && !waiter.isCompleted) waiter.complete(null);
      }
      refreshVoiceNavigation();
    });
  }
}
