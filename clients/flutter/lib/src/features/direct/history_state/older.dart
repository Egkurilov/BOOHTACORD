import '../../conversation/lifecycle/controller.dart';

extension ConversationLoadOlderDirectMessages on ConversationController {
  Future<bool> loadOlderDirectMessages() async {
    final active = admission(selection: true);
    if (!active()) return false;
    final conversation = selectedDirectMessage;
    final cursor = nextDirectMessageCursor;
    if (conversation == null || cursor == null || loadingOlderDirectMessages) {
      return false;
    }
    loadingOlderDirectMessages = true;
    changed();
    try {
      final page = await api.directMessageHistoryPage(
        conversation.id,
        before: cursor,
      );
      if (!active()) return false;
      if (selectedDirectMessage?.id != conversation.id) return false;
      final byId = {
        for (final message in directMessageHistory) message.id: message,
      };
      for (final message in page.messages) {
        final existing = byId[message.id];
        if (existing == null || message.revision >= existing.revision) {
          byId[message.id] = message;
        }
      }
      acknowledgeMessageIds(
        page.messages.map((message) => message.clientMessageId),
      );
      directMessageHistory = withPendingDirect(conversation.id, byId.values);
      nextDirectMessageCursor = page.nextCursor;
      return true;
    } catch (cause) {
      if (!active()) return false;
      error = formatError(cause);
      return false;
    } finally {
      if (active()) {
        loadingOlderDirectMessages = false;
        changed();
      }
    }
  }
}
