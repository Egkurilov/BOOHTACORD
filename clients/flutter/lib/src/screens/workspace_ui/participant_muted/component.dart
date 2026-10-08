import '../native_bindings.dart';

bool workspaceParticipantMuted(RemoteParticipant participant) {
  final publications = participant.audioTrackPublications;
  return publications.isEmpty || publications.every((item) => item.muted);
}
