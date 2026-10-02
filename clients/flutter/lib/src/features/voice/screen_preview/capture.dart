import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_thumbnail.dart';
import '../lifecycle/controller.dart';

extension VoiceScreenPreviewCapture on VoiceController {
  bool isRemoteScreenPublicationActive(
    Room room,
    RemoteParticipant participant,
    RemoteTrackPublication publication,
  ) =>
      !disposed &&
      scope.capture().isActive &&
      identical(this.room, room) &&
      screenPreviewSubscriptionQueue?.isClosed == false &&
      identical(room.remoteParticipants[participant.identity], participant) &&
      participant.videoTrackPublications.any(
        (item) => identical(item, publication),
      );

  Future<void> captureRemoteThumbnail(
    Room room,
    RemoteParticipant participant,
    RemoteTrackPublication publication,
    RemoteVideoTrack track,
  ) async {
    bool isActive() =>
        isRemoteScreenPublicationActive(room, participant, publication) &&
        identical(publication.track, track);

    final thumbnail = await captureRemoteScreenThumbnail(
      hasDecodedFrames: () async {
        final decoded = (await track.getReceiverStats())?.framesDecoded;
        return decoded != null && decoded > 0;
      },
      capture: () => screenThumbnailCaptureQueue.run(
        () async => (await track.mediaStreamTrack.captureFrame()).asUint8List(),
      ),
      encode: (frame) => compute(encodeScreenThumbnail, frame),
      isActive: isActive,
    );
    if (thumbnail == null || !isActive()) return;
    screenThumbnails[participant.identity] = thumbnail;
    notifyListeners();
  }

  void closeScreenPreviewSubscriptions() {
    screenPreviewSubscriptionQueue?.close();
    screenPreviewSubscriptionQueue = null;
    for (final waiter in screenPreviewTrackWaiters.values) {
      if (!waiter.isCompleted) waiter.complete(null);
    }
    screenPreviewTrackWaiters.clear();
    screenThumbnailRemoteTrackIds.clear();
  }
}
