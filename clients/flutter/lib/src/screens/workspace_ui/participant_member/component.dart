import '../native_bindings.dart';

GuildMember? workspaceParticipantMember(
  AppState state,
  RemoteParticipant participant,
) {
  final metadata = participant.metadata;
  if (metadata == null || !metadata.startsWith('account:')) return null;
  final accountId = metadata.substring('account:'.length);
  return state.members.where((member) => member.id == accountId).firstOrNull;
}
