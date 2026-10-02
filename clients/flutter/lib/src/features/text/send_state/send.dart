import '../../conversation/lifecycle/controller.dart';

extension ConversationSend on ConversationController {
  Future<bool> send(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) async {
    final active = admission(selection: false);
    if (!active()) return false;
    final channel = selectedChannel;
    final trimmed = body.trim();
    if (channel == null ||
        channel.kind != ChannelKind.text ||
        sending ||
        trimmed.isEmpty && attachments.isEmpty ||
        trimmed.runes.length > 8000) {
      return false;
    }
    final mentions = mentionUserIds.take(100).toSet().toList();
    final attachmentIds = attachments.map((item) => item.id).toList();
    final retryKey = sendRetryKey(
      'text',
      channel.id,
      trimmed,
      replyToId,
      mentions,
      attachmentIds,
    );
    final clientMessageId = sendRetryIds.putIfAbsent(retryKey, uuid.v4);
    final pending =
        pendingTextSends[clientMessageId] ??
        ChatMessage(
          id: 'optimistic:$clientMessageId',
          channelId: channel.id,
          authorId: user?.accountId ?? '',
          body: trimmed,
          createdAt: DateTime.now(),
          deleted: false,
          revision: 0,
          clientMessageId: clientMessageId,
          replyToId: replyToId,
          mentionUserIds: mentions,
          attachments: attachments,
        );
    pendingTextSends[clientMessageId] = pending.withSendStatus(
      MessageSendStatus.sending,
    );
    messages = withPendingText(channel.id, messages);
    sending = true;
    error = null;
    changed();
    try {
      final message = await api.sendMessage(
        channel.id,
        clientMessageId,
        trimmed,
        replyToId: replyToId,
        mentionUserIds: mentions,
        attachmentIds: attachmentIds,
      );
      if (!active()) return false;
      sendRetryIds.remove(retryKey);
      pendingTextSends.remove(clientMessageId);
      if (isReady() && selectedChannel?.id == channel.id) {
        messages = [
          ...messages.where(
            (value) =>
                value.id != message.id &&
                value.clientMessageId != clientMessageId,
          ),
          message,
        ];
      }
      return true;
    } catch (cause) {
      if (!active()) return false;
      if (pendingTextSends.containsKey(clientMessageId)) {
        pendingTextSends[clientMessageId] = pending.withSendStatus(
          MessageSendStatus.failed,
        );
        if (selectedChannel?.id == channel.id) {
          messages = withPendingText(channel.id, messages);
        }
      }
      if (isReady() && selectedChannel?.id == channel.id) {
        error = formatError(cause);
      }
      return false;
    } finally {
      if (active()) {
        sending = false;
        changed();
      }
    }
  }
}
