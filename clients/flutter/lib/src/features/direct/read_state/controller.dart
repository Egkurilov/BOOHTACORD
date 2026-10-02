import '../../conversation/lifecycle/controller.dart';

extension ConversationMarkSelectedDirectMessageRead on ConversationController {
  Future<void> markSelectedDirectMessageRead() async {
    final active = admission(selection: true);
    if (!active()) return;
    final conversation = selectedDirectMessage;
    if (conversation == null || loadingDirectMessages) return;
    final visibleOtherMessages = directMessageHistory
        .where(
          (message) =>
              message.sendStatus == null && message.authorId != user?.accountId,
        )
        .toList();
    if (visibleOtherMessages.isEmpty) return;
    final messageId = visibleOtherMessages.last.id;
    if (lastReadDirectMessageId == messageId) return;
    lastReadDirectMessageId = messageId;
    try {
      await api.advanceDirectMessageReadCursor(conversation.id, messageId);
      if (!active()) return;
      if (selectedDirectMessage?.id != conversation.id) return;
      directMessages = directMessages
          .map(
            (value) =>
                value.id == conversation.id ? value.withUnreadCount(0) : value,
          )
          .toList(growable: false);
      changed();
    } catch (cause) {
      if (!active()) return;
      lastReadDirectMessageId = null;
      error = formatError(cause);
      changed();
    }
  }
}
