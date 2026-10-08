import '../../mention_display_name/component.dart';
import '../../message_snippet/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceReplyPreviewBinding
    on WorkspaceConversationStateContext {
  @override
  String? workspaceReplyPreview(ChatMessage message) {
    return executeWorkspaceConversationStateWorkspaceReplyPreview(message);
  }
}

extension WorkspaceConversationStateWorkspaceReplyPreviewAction
    on WorkspaceConversationStateContext {
  String? executeWorkspaceConversationStateWorkspaceReplyPreview(
    ChatMessage message,
  ) {
    final replyToId = message.replyToId;
    if (replyToId == null) return null;
    final target = widget.state.messages
        .where((candidate) => candidate.id == replyToId)
        .firstOrNull;
    if (target == null) return 'Исходное сообщение недоступно';
    if (target.deleted) return 'Сообщение удалено';
    return '${workspaceMentionDisplayName(widget.state, target.authorId)}: ${workspaceMessageSnippet(target.body)}';
  }
}
