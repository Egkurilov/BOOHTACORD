import '../../conversation/lifecycle/controller.dart';

extension ConversationLoadOlderMessages on ConversationController {
  Future<bool> loadOlderMessages() async {
    final active = admission(selection: true);
    if (!active()) return false;
    final channel = selectedChannel;
    final cursor = nextMessageCursor;
    if (channel == null ||
        channel.kind != ChannelKind.text ||
        cursor == null ||
        loadingOlderMessages) {
      return false;
    }
    loadingOlderMessages = true;
    changed();
    try {
      final page = await api.messagePage(channel.id, before: cursor);
      if (!active()) return false;
      if (selectedChannel?.id != channel.id) return false;
      textHistoryHasLoadedOlderPages = true;
      final byId = {for (final message in messages) message.id: message};
      for (final message in page.messages) {
        byId.putIfAbsent(message.id, () => message);
      }
      acknowledgeMessageIds(
        page.messages.map((message) => message.clientMessageId),
      );
      messages = withPendingText(channel.id, byId.values);
      nextMessageCursor = page.nextCursor;
      return true;
    } catch (cause) {
      if (!active()) return false;
      error = formatError(cause);
      return false;
    } finally {
      if (active()) {
        loadingOlderMessages = false;
        changed();
      }
    }
  }
}
