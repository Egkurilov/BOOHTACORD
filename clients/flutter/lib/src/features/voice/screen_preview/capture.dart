import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/screen_thumbnail.dart';
import '../../../services/screen_thumbnail_remote_capture.dart';
import '../lifecycle/controller.dart';

extension VoiceScreenPreviewCapture on VoiceController {
  void removeRemoteScreenThumbnail(
    String identity, {
    RemoteTrackPublication? publication,
  }) {
    final capturedPublication = screenThumbnailPublications[identity];
    if (publication != null &&
        capturedPublication != null &&
        !identical(capturedPublication, publication)) {
      return;
    }
    screenThumbnailPublications.remove(identity);
    screenThumbnails.remove(identity);
  }

  bool isRemoteScreenPublicationActive(
    Room room,
    RemoteParticipant participant,
    RemoteTrackPublication publication,
  ) =>
      !disposed &&
      scope.capture().isActive &&
      identical(this.room, room) &&
      selectedRemoteScreenViewerIdentity == participant.identity &&
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
    final selectionRevision = screenViewerSelectionRevision;
    bool isActive() =>
        isRemoteScreenPublicationActive(room, participant, publication) &&
        selectionRevision == screenViewerSelectionRevision &&
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
    screenThumbnailPublications[participant.identity] = publication;
    screenThumbnails[participant.identity] = thumbnail;
    notifyListeners();
  }

}
