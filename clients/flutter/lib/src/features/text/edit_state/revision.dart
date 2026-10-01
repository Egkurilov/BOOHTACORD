import '../../conversation/lifecycle/controller.dart';

extension ConversationRefreshTextMessageRevision on ConversationController {
  Future<ChatMessage?> refreshTextMessageRevision(ChatMessage message) async {
    final active = admission(selection: true);
    if (!active()) return null;
    final target = message.channelId;
    if (selectedChannel?.id != target ||
        !messages.any((item) => item.id == message.id)) {
      return null;
    }
    final count = messages.where((item) => item.sendStatus == null).length;
    final maxPages = (count + 49) ~/ 50 + 2;
    final seen = <String>{};
    String? before;
    try {
      for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
        final page = await api.messagePage(target, before: before);
        if (!active()) return null;
        if (selectedChannel?.id != target) return null;
        final found = page.messages
            .where((item) => item.id == message.id)
            .firstOrNull;
        if (found != null) {
          messages = messages
              .map(
                (item) => item.id == found.id && found.revision >= item.revision
                    ? found
                    : item,
              )
              .toList(growable: false);
          error = null;
          changed();
          return messages.where((item) => item.id == found.id).firstOrNull;
        }
        final cursor = page.nextCursor;
        if (cursor == null || !seen.add(cursor)) break;
        before = cursor;
      }
    } catch (cause) {
      if (!active()) return null;
      if (selectedChannel?.id == target) {
        error = formatError(cause);
        changed();
      }
    }
    return null;
  }
}
