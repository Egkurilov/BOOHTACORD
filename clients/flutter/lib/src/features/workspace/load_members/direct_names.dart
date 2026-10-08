import '../../../models.dart';
import '../lifecycle/controller.dart';

void updateDirectNamesForMember(
  WorkspaceController workspace,
  String userId,
  String displayName,
) {
  DirectConversation rename(DirectConversation value) => DirectConversation(
    id: value.id,
    participantId: value.participantId,
    displayName: displayName,
    unreadCount: value.unreadCount,
  );

  workspace.directMessages = workspace.directMessages
      .map((value) => value.participantId == userId ? rename(value) : value)
      .toList(growable: false);
  final selected = workspace.selectedDirectMessage;
  if (selected?.participantId == userId) {
    workspace.selectedDirectMessage = rename(selected!);
  }
}
