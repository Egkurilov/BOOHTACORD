import '../../conversation/lifecycle/controller.dart';

extension ConversationDeleteText on ConversationController {
  Future<void> deleteText(ChatMessage message) async {
    final active = admission(selection: true);
    if (!active()) return;
    try {
      await api.deleteMessage(message.channelId, message.id);
      if (!active()) return;
      if (selectedChannel?.id == message.channelId) {
        messages = messages
            .map(
              (item) => item.id == message.id && !item.deleted
                  ? item.asDeleted()
                  : item,
            )
            .toList(growable: false);
        error = null;
        changed();
      }
    } catch (cause) {
      if (!active()) return;
      if (selectedChannel?.id == message.channelId) {
        error = formatError(cause);
        changed();
      }
    }
  }
}
