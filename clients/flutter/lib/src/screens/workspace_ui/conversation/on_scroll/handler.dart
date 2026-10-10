import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceOnScrollBinding
    on WorkspaceConversationStateContext {
  @override
  void workspaceOnScroll() {
    executeWorkspaceConversationStateWorkspaceOnScroll();
  }
}

extension WorkspaceConversationStateWorkspaceOnScrollAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateWorkspaceOnScroll() {
    if (!workspaceScroll.hasClients) return;
    workspaceFollowLatest = workspaceScroll.position.extentAfter <= 48;
    workspaceRememberScrollPosition();
    workspaceScheduleVisibleRead(widget.state.messages);
  }
}
