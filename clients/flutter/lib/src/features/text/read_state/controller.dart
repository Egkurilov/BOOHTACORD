import '../../conversation/lifecycle/controller.dart';

int _compareReadCursor(
  ({DateTime createdAt, String messageId}) left,
  ({DateTime createdAt, String messageId}) right,
) {
  final byCreatedAt = left.createdAt.compareTo(right.createdAt);
  return byCreatedAt != 0
      ? byCreatedAt
      : left.messageId.compareTo(right.messageId);
}

extension ConversationMarkTextChannelRead on ConversationController {
  Future<void> markTextChannelRead(String channelId, String messageId) async {
    final active = admission(selection: true);
    final accountActive = admission();
    if (!active()) return;
    if (!isReady() ||
        selectedChannel?.id != channelId ||
        selectedChannel?.kind != ChannelKind.text) {
      return;
    }
    final message = messages
        .where(
          (candidate) =>
              candidate.id == messageId &&
              !candidate.deleted &&
              candidate.sendStatus == null,
        )
        .firstOrNull;
    if (message == null) return;
    final cursor = (createdAt: message.createdAt, messageId: message.id);
    final lastRead = lastReadTextCursor[channelId];
    if (lastRead != null && _compareReadCursor(cursor, lastRead) <= 0) return;
    final pendingRead = pendingTextReadCursor[channelId];
    if (pendingRead != null && _compareReadCursor(cursor, pendingRead) <= 0) {
      return;
    }
    final key = '$channelId:$messageId';
    if (!pendingTextReads.add(key)) return;
    pendingTextReadCursor[channelId] = cursor;
    try {
      await api.advanceTextChannelReadCursor(channelId, messageId);
      if (!active()) return;
      final latestRead = lastReadTextCursor[channelId];
      if (latestRead == null || _compareReadCursor(cursor, latestRead) > 0) {
        lastReadTextCursor[channelId] = cursor;
      }
      if (!isReady() || selectedChannel?.id != channelId) return;
      final updated = await api.topology();
      if (!active()) return;
      if (!isReady() || selectedChannel?.id != channelId) return;
      topology = updated;
      selectedChannel = updated.categories
          .expand((category) => category.channels)
          .where((channel) => channel.id == channelId)
          .firstOrNull;
      changed();
    } catch (_) {
      // Keep server-provided counts until a visible retry succeeds.
    } finally {
      if (accountActive()) {
        pendingTextReads.remove(key);
        if (pendingTextReadCursor[channelId] == cursor) {
          pendingTextReadCursor.remove(channelId);
        }
      }
    }
  }
}
