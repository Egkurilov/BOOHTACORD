import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceRememberDraftBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void workspaceRememberDraft() {
    executeWorkspaceDirectConversationStateWorkspaceRememberDraft();
  }
}

extension WorkspaceDirectConversationStateWorkspaceRememberDraftAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateWorkspaceRememberDraft() =>
      workspaceRememberDraftFor(widget.conversation.id);
}
