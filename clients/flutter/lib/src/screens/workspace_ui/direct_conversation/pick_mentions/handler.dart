import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspacePickMentionsBinding
    on WorkspaceDirectConversationStateContext {
  @override
  Future<void> workspacePickMentions() {
    return executeWorkspaceDirectConversationStateWorkspacePickMentions();
  }
}

extension WorkspaceDirectConversationStateWorkspacePickMentionsAction
    on WorkspaceDirectConversationStateContext {
  Future<void>
  executeWorkspaceDirectConversationStateWorkspacePickMentions() async {
    final selected = await showMessageMentionDialog(
      context: context,
      options: [
        (widget.conversation.participantId, widget.conversation.displayName),
      ],
      selfId: widget.state.user?.accountId ?? '',
      selectedIds: workspaceMentionUserIds,
    );
    if (!mounted || selected == null) return;
    workspaceMutateView(() {
      workspaceMentionUserIds
        ..clear()
        ..addAll(selected);
    });
    workspaceRememberDraft();
  }
}
