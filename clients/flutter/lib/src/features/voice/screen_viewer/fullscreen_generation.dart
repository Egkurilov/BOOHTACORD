import 'package:livekit_client/livekit_client.dart';

import 'discovery.dart';
import 'publication_generation.dart';

Object? localScreenFullscreenGeneration({
  required String? publicationSid,
  required Object? track,
}) =>
    publicationSid ?? track;

ScreenViewerPublicationGeneration remoteScreenFullscreenGeneration({
  required String participantIdentity,
  required String publicationSid,
}) =>
    ScreenViewerPublicationGeneration(
      participantIdentity: participantIdentity,
      publicationSid: publicationSid,
    );

bool screenFullscreenGenerationIsCurrent({
  required String? selectionIdentity,
  required Object? selectionGeneration,
  required String? currentIdentity,
  required Object? currentGeneration,
}) =>
    selectionIdentity == currentIdentity &&
    selectionGeneration == currentGeneration;

bool screenFullscreenGenerationIsPublished({
  required Room? room,
  required String? publisherIdentity,
  required Object viewerGeneration,
  required bool localCaptureActive,
}) {
  if (publisherIdentity == null) {
    if (!localCaptureActive) return false;
    final publication = room?.localParticipant?.getTrackPublicationBySource(
      TrackSource.screenShareVideo,
    );
    return screenFullscreenGenerationIsCurrent(
      selectionIdentity: null,
      selectionGeneration: viewerGeneration,
      currentIdentity: null,
      currentGeneration: localScreenFullscreenGeneration(
        publicationSid: publication?.sid,
        track: publication?.track,
      ),
    );
  }

  final participant = room?.remoteParticipants[publisherIdentity];
  if (participant == null) return false;
  final publication = firstDiscoverableRemoteScreenPublication(participant);
  if (publication == null) return false;
  return screenFullscreenGenerationIsCurrent(
    selectionIdentity: publisherIdentity,
    selectionGeneration: viewerGeneration,
    currentIdentity: participant.identity,
    currentGeneration: remoteScreenFullscreenGeneration(
      participantIdentity: participant.identity,
      publicationSid: publication.sid,
    ),
  );
}
