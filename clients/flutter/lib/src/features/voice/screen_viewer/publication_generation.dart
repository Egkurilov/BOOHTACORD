import 'package:flutter/foundation.dart';

@immutable
class ScreenViewerPublicationGeneration {
  const ScreenViewerPublicationGeneration({
    required this.participantIdentity,
    required this.publicationSid,
  });

  final String participantIdentity;
  final String publicationSid;

  @override
  bool operator ==(Object other) =>
      other is ScreenViewerPublicationGeneration &&
      other.participantIdentity == participantIdentity &&
      other.publicationSid == publicationSid;

  @override
  int get hashCode => Object.hash(participantIdentity, publicationSid);
}
