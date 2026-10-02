import 'dart:async';

import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_thumbnail.dart';
import '../lifecycle/controller.dart';

extension VoiceScreenPreviewQueue on VoiceController {
  void queueRemoteScreenThumbnail(
    Room room,
    RemoteParticipant participant,
    RemoteTrackPublication publication,
  ) {
    final queue = screenPreviewSubscriptionQueue;
    if (queue == null ||
        queue.isClosed ||
        publication.source != TrackSource.screenShareVideo ||
        publication.muted ||
        selectedRemoteScreenViewerIdentity == participant.identity) {
      return;
    }
    unawaited(
      queue.enqueue(publication.sid, () async {
        if (!isRemoteScreenPublicationActive(room, participant, publication) ||
            selectedRemoteScreenViewerIdentity == participant.identity) {
          return;
        }
        final trackId = publication.sid;
        final waiter = Completer<RemoteVideoTrack?>();
        screenPreviewTrackWaiters[trackId] = waiter;
        screenThumbnailRemoteTrackIds[trackId] = participant.identity;
        try {
          final existingTrack = publication.track;
          if (existingTrack is RemoteVideoTrack) {
            waiter.complete(existingTrack);
          }
          final track =
              await withTemporaryScreenPreviewSubscription<RemoteVideoTrack>(
                subscribe: publication.subscribe,
                action: () => waiter.future.timeout(
                  const Duration(seconds: 4),
                  onTimeout: () => null,
                ),
                unsubscribe: publication.unsubscribe,
                keepSubscribed: () =>
                    selectedRemoteScreenViewerIdentity == participant.identity,
              );
          if (track == null ||
              selectedRemoteScreenViewerIdentity == participant.identity ||
              !isRemoteScreenPublicationActive(
                room,
                participant,
                publication,
              )) {
            return;
          }
          await captureRemoteThumbnail(room, participant, publication, track);
        } catch (_) {
          // A failed thumbnail subscription must not affect voice playback.
        } finally {
          if (identical(screenPreviewTrackWaiters[trackId], waiter)) {
            screenPreviewTrackWaiters.remove(trackId);
          }
          screenThumbnailRemoteTrackIds.remove(trackId);
          if (isRemoteScreenPublicationActive(room, participant, publication) &&
              selectedRemoteScreenViewerIdentity == participant.identity) {
            // A selection can race the temporary unsubscribe's completion.
            // Restore persistent playback after the preview has left the queue.
            await setRemoteTrackSubscription(publication, true);
          }
        }
      }),
    );
  }
}
