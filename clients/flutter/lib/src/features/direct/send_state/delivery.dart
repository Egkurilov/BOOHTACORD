import '../../conversation/lifecycle/controller.dart';
import '../../conversation/delivery/recovery.dart';

extension DirectDelivery on ConversationController {
  Future<DirectChatMessage> deliverDirect(
    DirectChatMessage draft,
    bool retry,
    bool Function() active,
  ) => recoverDelivery<DirectChatMessage>(
    post: () => api.sendDirectMessage(
      draft.directMessageId,
      draft.clientMessageId!,
      draft.body,
      replyToId: draft.replyToId,
      mentionUserIds: draft.mentionUserIds,
      attachmentIds: draft.attachments.map((row) => row.id).toList(),
    ),
    lookup: () => api.findSentDirect(
      draft.directMessageId,
      draft.clientMessageId!,
      draft.authorId,
    ),
    status: (status) {
      if (!active() || !pendingDirectSends.containsKey(draft.clientMessageId)) {
        return;
      }
      pendingDirectSends[draft.clientMessageId!] = draft.withSendStatus(
        status == 'checking'
            ? MessageSendStatus.checking
            : MessageSendStatus.sending,
      );
      if (selectedDirectMessage?.id == draft.directMessageId) {
        directMessageHistory = withPendingDirect(
          draft.directMessageId,
          directMessageHistory,
        );
      }
      changed();
    },
    active: active,
    retry: retry,
  );
}
