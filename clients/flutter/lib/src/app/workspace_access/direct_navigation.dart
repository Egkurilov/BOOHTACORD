import '../../models.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppDirectNavigationAccess on AppOwners {
  List<DirectConversation> get directMessages => workspace.directMessages;

  set directMessages(List<DirectConversation> value) =>
      workspace.directMessages = value;

  List<DirectCandidate> get directMessageCandidates =>
      workspace.directMessageCandidates;

  set directMessageCandidates(List<DirectCandidate> value) =>
      workspace.directMessageCandidates = value;

  DirectConversation? get selectedDirectMessage =>
      workspace.selectedDirectMessage;

  set selectedDirectMessage(DirectConversation? value) =>
      workspace.selectedDirectMessage = value;

  Future<void> refreshDirectMessages() => workspace.refreshDirectMessages();

  Future<void> showDirectMessages() => workspace.showDirectMessages();

  Future<void> openDirectConversation(DirectConversation conversation) =>
      workspace.openDirectConversation(conversation);

  Future<void> createDirectConversation(DirectCandidate candidate) =>
      workspace.createDirectConversation(candidate);
}
