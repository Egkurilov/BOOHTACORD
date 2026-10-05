import '../../conversation/lifecycle/controller.dart';
import '../../conversation/delivery/recovery.dart';

extension TextDelivery on ConversationController {
  Future<ChatMessage> deliverText(
    ChatMessage draft,
    bool retry,
    bool Function() active,
  ) => recoverDelivery<ChatMessage>(
    post: () => api.sendMessage(
      draft.channelId,
      draft.clientMessageId!,
      draft.body,
      replyToId: draft.replyToId,
      mentionUserIds: draft.mentionUserIds,
      attachmentIds: draft.attachments.map((row) => row.id).toList(),
    ),
    lookup: () => api.findSentText(
      draft.channelId,
      draft.clientMessageId!,
      draft.authorId,
    ),
    status: (status) {
      if (!active() || !pendingTextSends.containsKey(draft.clientMessageId)) {
        return;
      }
      pendingTextSends[draft.clientMessageId!] = draft.withSendStatus(
        status == 'checking'
            ? MessageSendStatus.checking
            : MessageSendStatus.sending,
      );
      if (selectedChannel?.id == draft.channelId) {
        messages = withPendingText(draft.channelId, messages);
      }
      changed();
    },
    active: active,
    retry: retry,
  );
}
