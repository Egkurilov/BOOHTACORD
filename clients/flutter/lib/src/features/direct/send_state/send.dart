import '../../conversation/lifecycle/controller.dart';

extension ConversationSendDirect on ConversationController {
  Future<bool> sendDirect(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) async {
    final active = admission(selection: false);
    if (!active()) return false;
    final conversation = selectedDirectMessage;
    final trimmed = body.trim();
    if (conversation == null ||
        sending ||
        trimmed.isEmpty && attachments.isEmpty ||
        trimmed.runes.length > 8000) {
      return false;
    }
    final mentions = mentionUserIds.take(100).toSet().toList();
    final attachmentIds = attachments.map((item) => item.id).toList();
    final retryKey = sendRetryKey(
      'dm',
      conversation.id,
      trimmed,
      replyToId,
      mentions,
      attachmentIds,
    );
    final clientMessageId = sendRetryIds.putIfAbsent(retryKey, uuid.v4);
    final pending =
        pendingDirectSends[clientMessageId] ??
        DirectChatMessage(
          id: 'optimistic:$clientMessageId',
          directMessageId: conversation.id,
          authorId: user?.accountId ?? '',
          body: trimmed,
          createdAt: DateTime.now(),
          deleted: false,
          revision: 0,
          clientMessageId: clientMessageId,
          mentionUserIds: mentions,
          replyToId: replyToId,
          attachments: attachments,
        );
    pendingDirectSends[clientMessageId] = pending.withSendStatus(
      MessageSendStatus.sending,
    );
    if (selectedDirectMessage?.id == conversation.id) {
      directMessageHistory = withPendingDirect(
        conversation.id,
        directMessageHistory,
      );
    }
    sending = true;
    error = null;
    changed();
    try {
      final message = await api.sendDirectMessage(
        conversation.id,
        clientMessageId,
        trimmed,
        replyToId: replyToId,
        mentionUserIds: mentions,
        attachmentIds: attachmentIds,
      );
      if (!active()) return false;
      sendRetryIds.remove(retryKey);
      pendingDirectSends.remove(clientMessageId);
      if (isReady() && selectedDirectMessage?.id == conversation.id) {
        directMessageHistory = [
          ...directMessageHistory.where(
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
      if (pendingDirectSends.containsKey(clientMessageId)) {
        pendingDirectSends[clientMessageId] = pending.withSendStatus(
          MessageSendStatus.failed,
        );
        if (selectedDirectMessage?.id == conversation.id) {
          directMessageHistory = withPendingDirect(
            conversation.id,
            directMessageHistory,
          );
        }
      }
      if (isReady() && selectedDirectMessage?.id == conversation.id) {
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
