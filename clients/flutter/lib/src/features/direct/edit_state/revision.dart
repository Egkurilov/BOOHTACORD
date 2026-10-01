import '../../conversation/lifecycle/controller.dart';

extension ConversationRefreshDirectMessageRevision on ConversationController {
  Future<DirectChatMessage?> refreshDirectMessageRevision(
    DirectChatMessage message,
  ) async {
    final active = admission(selection: true);
    if (!active()) return null;
    final target = message.directMessageId;
    if (selectedDirectMessage?.id != target ||
        !directMessageHistory.any((item) => item.id == message.id)) {
      return null;
    }
    final count = directMessageHistory
        .where((item) => item.sendStatus == null)
        .length;
    final maxPages = (count + 49) ~/ 50 + 2;
    final seen = <String>{};
    String? before;
    try {
      for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
        final page = await api.directMessageHistoryPage(target, before: before);
        if (!active()) return null;
        if (selectedDirectMessage?.id != target) return null;
        final found = page.messages
            .where((item) => item.id == message.id)
            .firstOrNull;
        if (found != null) {
          directMessageHistory = directMessageHistory
              .map(
                (item) => item.id == found.id && found.revision >= item.revision
                    ? found
                    : item,
              )
              .toList(growable: false);
          error = null;
          changed();
          return directMessageHistory
              .where((item) => item.id == found.id)
              .firstOrNull;
        }
        final cursor = page.nextCursor;
        if (cursor == null || !seen.add(cursor)) break;
        before = cursor;
      }
    } catch (cause) {
      if (!active()) return null;
      if (selectedDirectMessage?.id == target) {
        error = formatError(cause);
        changed();
      }
    }
    return null;
  }
}
