import '../../conversation/lifecycle/controller.dart';

extension ConversationRetryDirectSend on ConversationController {
  Future<bool> retryDirectSend(String clientMessageId) async {
    final active = admission(selection: false);
    if (!active()) return false;
    final pending = pendingDirectSends[clientMessageId];
    if (pending == null ||
        pending.sendStatus != MessageSendStatus.failed ||
        selectedDirectMessage?.id != pending.directMessageId) {
      return false;
    }
    return sendDirect(
      pending.body,
      replyToId: pending.replyToId,
      mentionUserIds: pending.mentionUserIds,
      attachments: pending.attachments,
    );
  }
}
