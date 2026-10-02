import '../../conversation/lifecycle/controller.dart';

extension ConversationDeleteDirect on ConversationController {
  Future<void> deleteDirect(DirectChatMessage message) async {
    final active = admission(selection: true);
    if (!active()) return;
    try {
      await api.deleteDirectMessage(message.directMessageId, message.id);
      if (!active()) return;
      if (selectedDirectMessage?.id == message.directMessageId) {
        directMessageHistory = directMessageHistory
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
      if (selectedDirectMessage?.id == message.directMessageId) {
        error = formatError(cause);
        changed();
      }
    }
  }
}
