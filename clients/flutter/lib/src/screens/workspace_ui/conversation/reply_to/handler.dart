import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceReplyToBinding
    on WorkspaceConversationStateContext {
  @override
  void workspaceReplyTo(ChatMessage message) {
    executeWorkspaceConversationStateWorkspaceReplyTo(message);
  }
}

extension WorkspaceConversationStateWorkspaceReplyToAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateWorkspaceReplyTo(ChatMessage message) {
    workspaceMutateView(() => workspaceReplyTarget = message);
    workspaceRememberDraft();
    workspaceComposerFocus.requestFocus();
  }
}
