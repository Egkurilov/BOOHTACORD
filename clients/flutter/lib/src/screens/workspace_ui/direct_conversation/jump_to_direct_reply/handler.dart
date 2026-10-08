import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceJumpToDirectReplyBinding
    on WorkspaceDirectConversationStateContext {
  @override
  void workspaceJumpToDirectReply(DirectChatMessage message) {
    executeWorkspaceDirectConversationStateWorkspaceJumpToDirectReply(message);
  }
}

extension WorkspaceDirectConversationStateWorkspaceJumpToDirectReplyAction
    on WorkspaceDirectConversationStateContext {
  void executeWorkspaceDirectConversationStateWorkspaceJumpToDirectReply(
    DirectChatMessage message,
  ) {
    final targetId = message.replyToId;
    if (targetId == null) return;
    final context =
        workspaceDirectMessageKeys['${widget.conversation.id}:$targetId']
            ?.currentContext;
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
    unawaited(
      widget.state.openSearchContext(
        SearchMessage(
          id: targetId,
          kind: SearchMessageKind.directMessage,
          conversationId: widget.conversation.id,
          authorId: message.authorId,
          body: message.body,
          createdAt: message.createdAt,
          revision: message.revision,
        ),
        heading: 'Контекст ответа',
      ),
    );
  }
}
