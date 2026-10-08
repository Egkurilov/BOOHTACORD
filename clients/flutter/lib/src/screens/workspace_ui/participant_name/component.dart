import '../native_bindings.dart';

String workspaceParticipantName(RemoteParticipant participant) =>
    participant.name.trim().isNotEmpty
    ? participant.name
    : participant.identity;
