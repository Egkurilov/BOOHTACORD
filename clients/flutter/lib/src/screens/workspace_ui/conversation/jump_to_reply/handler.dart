import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceJumpToReplyBinding
    on WorkspaceConversationStateContext {
  @override
  Future<void> workspaceJumpToReply(ChatMessage message) {
    return executeWorkspaceConversationStateWorkspaceJumpToReply(message);
  }
}

extension WorkspaceConversationStateWorkspaceJumpToReplyAction
    on WorkspaceConversationStateContext {
  Future<void> executeWorkspaceConversationStateWorkspaceJumpToReply(
    ChatMessage message,
  ) async {
    final targetId = message.replyToId;
    if (targetId == null) return;
    final context =
        workspaceMessageKeys['${widget.channel.id}:$targetId']?.currentContext;
    if (context != null) {
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 220),
          alignment: 0.25,
        ),
      );
      return;
    }
    await widget.state.openSearchContext(
      SearchMessage(
        id: targetId,
        kind: SearchMessageKind.channel,
        conversationId: widget.channel.id,
        authorId: message.authorId,
        body: message.body,
        createdAt: message.createdAt,
        revision: message.revision,
      ),
      heading: 'Контекст ответа',
    );
  }
}
