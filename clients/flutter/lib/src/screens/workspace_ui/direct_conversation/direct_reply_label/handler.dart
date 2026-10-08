import '../../message_snippet/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceDirectReplyLabelBinding
    on WorkspaceDirectConversationStateContext {
  @override
  String? workspaceDirectReplyLabel(DirectChatMessage message) {
    return executeWorkspaceDirectConversationStateWorkspaceDirectReplyLabel(
      message,
    );
  }
}

extension WorkspaceDirectConversationStateWorkspaceDirectReplyLabelAction
    on WorkspaceDirectConversationStateContext {
  String? executeWorkspaceDirectConversationStateWorkspaceDirectReplyLabel(
    DirectChatMessage message,
  ) {
    final preview = message.replyPreview;
    if (preview != null) {
      if (preview.deleted) return 'Сообщение удалено';
      return '${workspaceDirectAuthorName(preview.authorId)}: ${workspaceMessageSnippet(preview.body)}';
    }
    final replyToId = message.replyToId;
    if (replyToId == null) return null;
    final target = widget.state.directMessageHistory
        .where((candidate) => candidate.id == replyToId)
        .firstOrNull;
    if (target == null) return 'Исходное сообщение недоступно';
    if (target.deleted) return 'Сообщение удалено';
    return '${workspaceDirectAuthorName(target.authorId)}: ${workspaceMessageSnippet(target.body)}';
  }
}
