import '../../conversation/lifecycle/controller.dart';

extension ConversationRetryTextSend on ConversationController {
  Future<bool> retryTextSend(String clientMessageId) async {
    final active = admission(selection: false);
    if (!active()) return false;
    final pending = pendingTextSends[clientMessageId];
    if (pending == null ||
        pending.sendStatus != MessageSendStatus.failed ||
        selectedChannel?.id != pending.channelId) {
      return false;
    }
    return send(
      pending.body,
      replyToId: pending.replyToId,
      mentionUserIds: pending.mentionUserIds,
      attachments: pending.attachments,
    );
  }
}
