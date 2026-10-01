import '../../conversation/lifecycle/controller.dart';

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
    final lastReadAt = lastReadTextAt[channelId];
    if (lastReadAt != null && !message.createdAt.isAfter(lastReadAt)) return;
    final pendingAt = pendingTextReadAt[channelId];
    if (pendingAt != null && !message.createdAt.isAfter(pendingAt)) return;
    final key = '$channelId:$messageId';
    if (!pendingTextReads.add(key)) return;
    pendingTextReadAt[channelId] = message.createdAt;
    try {
      await api.advanceTextChannelReadCursor(channelId, messageId);
      if (!active()) return;
      lastReadTextAt[channelId] = message.createdAt;
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
        if (pendingTextReadAt[channelId] == message.createdAt) {
          pendingTextReadAt.remove(channelId);
        }
      }
    }
  }
}
