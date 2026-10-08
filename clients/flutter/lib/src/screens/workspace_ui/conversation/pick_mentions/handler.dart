import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspacePickMentionsBinding
    on WorkspaceConversationStateContext {
  @override
  Future<void> workspacePickMentions() {
    return executeWorkspaceConversationStateWorkspacePickMentions();
  }
}

extension WorkspaceConversationStateWorkspacePickMentionsAction
    on WorkspaceConversationStateContext {
  Future<void> executeWorkspaceConversationStateWorkspacePickMentions() async {
    final selected = await showMessageMentionDialog(
      context: context,
      options: widget.state.members
          .map((member) => (member.id, member.displayName))
          .toList(growable: false),
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
