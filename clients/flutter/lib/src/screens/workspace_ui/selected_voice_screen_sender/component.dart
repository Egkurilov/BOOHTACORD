import '../native_bindings.dart';

RemoteParticipant? workspaceSelectedVoiceScreenSender(
  List<RemoteParticipant> screens,
  String? selectedIdentity,
) {
  if (selectedIdentity == null) return null;
  for (final participant in screens) {
    if (participant.identity == selectedIdentity) return participant;
  }
  return null;
}
