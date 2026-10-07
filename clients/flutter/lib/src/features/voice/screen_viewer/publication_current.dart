import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../lifecycle/controller.dart';

RemoteTrackPublication? currentRemoteScreenViewerPublication(
  VoiceController voice,
  RemoteTrackPublication publication,
) {
  final generation = voice.selectedRemoteScreenViewerGeneration;
  final participant = voice.room?.remoteParticipants[
    publication.participant.identity
  ];
  if (generation?.participantIdentity != publication.participant.identity ||
      generation?.publicationSid != publication.sid ||
      voice.selectedRemoteScreenViewerIdentity !=
          publication.participant.identity) {
    return null;
  }
  final current = participant?.videoTrackPublications
      .where((item) => item.sid == publication.sid)
      .firstOrNull;
  if (current == null ||
      current.source != TrackSource.screenShareVideo ||
      current.muted ||
      !current.subscriptionAllowed) {
    return null;
  }
  return current;
}
