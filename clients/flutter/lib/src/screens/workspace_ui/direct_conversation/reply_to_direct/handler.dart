import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceReplyToDirectBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void workspaceReplyToDirect(DirectChatMessage message) {
    executeWorkspaceDirectConversationStateWorkspaceReplyToDirect(message);
  }
}

extension WorkspaceDirectConversationStateWorkspaceReplyToDirectAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateWorkspaceReplyToDirect(
    DirectChatMessage message,
  ) {
    workspaceMutateView(() => workspaceReplyTarget = message);
    workspaceRememberDraft();
    workspaceComposerFocus.requestFocus();
  }
}
