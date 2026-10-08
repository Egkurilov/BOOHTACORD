import '../../mention_display_name/component.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceDirectAuthorNameBinding
    on WorkspaceDirectConversationStateContext {
  @override
  String workspaceDirectAuthorName(String accountId) {
    return executeWorkspaceDirectConversationStateWorkspaceDirectAuthorName(
      accountId,
    );
  }
}

extension WorkspaceDirectConversationStateWorkspaceDirectAuthorNameAction
    on WorkspaceDirectConversationStateContext {
  String executeWorkspaceDirectConversationStateWorkspaceDirectAuthorName(
    String accountId,
  ) {
    if (accountId == widget.state.user?.accountId) {
      return widget.state.profile?.displayName ?? 'Вы';
    }
    if (accountId == widget.conversation.participantId) {
      return widget.conversation.displayName;
    }
    return workspaceMentionDisplayName(widget.state, accountId).substring(1);
  }
}
