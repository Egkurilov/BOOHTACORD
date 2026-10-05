import 'controller.dart';

extension ConversationCancellation on ConversationController {
  void cancelOperations() {
    cacheGeneration++;
    invalidateSelection();
    sending = false;
    pendingTextReads.clear();
    pendingTextReadCursor.clear();
    lastReadDirectMessageId = null;
    pendingTextSends.updateAll(
      (_, message) => message.withSendStatus(MessageSendStatus.failed),
    );
    pendingDirectSends.updateAll(
      (_, message) => message.withSendStatus(MessageSendStatus.failed),
    );
    final channel = selectedChannel;
    if (channel != null) messages = withPendingText(channel.id, messages);
    final direct = selectedDirectMessage;
    if (direct != null) {
      directMessageHistory = withPendingDirect(direct.id, directMessageHistory);
    }
  }
}
