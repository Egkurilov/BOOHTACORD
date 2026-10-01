import '../../conversation/lifecycle/controller.dart';

extension ConversationWithPendingDirect on ConversationController {
  List<DirectChatMessage> withPendingDirect(
    String conversationId,
    Iterable<DirectChatMessage> history,
  ) {
    final confirmed = history
        .where((message) => message.sendStatus == null)
        .toList();
    final confirmedIds = confirmed
        .map((message) => message.clientMessageId)
        .toSet();
    final combined = [
      ...confirmed,
      ...pendingDirectSends.values.where(
        (message) =>
            message.directMessageId == conversationId &&
            !confirmedIds.contains(message.clientMessageId),
      ),
    ];
    combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return combined;
  }
}
