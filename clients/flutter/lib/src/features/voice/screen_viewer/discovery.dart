import 'package:livekit_client/livekit_client.dart';

bool isDiscoverableRemoteScreenPublication(
  RemoteTrackPublication publication,
) =>
    publication.source == TrackSource.screenShareVideo && !publication.muted;

RemoteTrackPublication? firstDiscoverableRemoteScreenPublication(
  RemoteParticipant participant,
) =>
    participant.videoTrackPublications
        .where(isDiscoverableRemoteScreenPublication)
        .firstOrNull;
