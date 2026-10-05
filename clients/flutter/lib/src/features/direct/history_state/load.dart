import '../../conversation/lifecycle/controller.dart';

extension ConversationLoadDirectHistory on ConversationController {
  Future<void> loadDirectHistory(DirectConversation conversation) async {
    invalidateSelection();
    final active = admission(selection: true);
    if (!active()) return;
    nextDirectMessageCursor = null;
    olderDirectHistoryError = null;
    loadingDirectMessages = true;
    error = null;
    changed();
    try {
      final page = await api.directMessageHistoryPage(conversation.id);
      if (!active()) return;
      if (selectedDirectMessage?.id == conversation.id) {
        acknowledgeMessageIds(
          page.messages.map((message) => message.clientMessageId),
        );
        directMessageHistory = withPendingDirect(
          conversation.id,
          page.messages,
        );
        nextDirectMessageCursor = page.nextCursor;
      }
    } catch (cause) {
      if (!active()) return;
      error = formatError(cause);
    } finally {
      if (active()) {
        loadingDirectMessages = false;
        changed();
      }
    }
  }
}
