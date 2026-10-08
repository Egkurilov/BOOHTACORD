import '../native_bindings.dart';

String? workspaceVoiceParticipantAccountId(RemoteParticipant participant) {
  final metadata = participant.metadata;
  if (metadata == null || !metadata.startsWith('account:')) return null;
  final id = metadata.substring('account:'.length);
  return id.isEmpty ? null : id;
}
