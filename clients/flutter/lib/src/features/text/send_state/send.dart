import '../../conversation/lifecycle/controller.dart';
import '../../conversation/delivery/recovery.dart';
import 'delivery.dart';

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
    final retry = pendingTextSends.containsKey(clientMessageId);
    if (blockedSendRetries.contains(clientMessageId)) return false;
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
    final action = sendObservation.begin(clientMessageId);
    try {
      final message = await action.run(
        () => deliverText(pending, retry, active),
      );
      if (!active()) return false;
      sendObservation.accepted(clientMessageId, message);
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
      sendObservation.failed(clientMessageId, cause);
      if (!active()) return false;
      if (!uncertainDelivery(cause)) blockedSendRetries.add(clientMessageId);
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
