import '../../conversation/lifecycle/controller.dart';

extension ConversationWithPendingText on ConversationController {
  List<ChatMessage> withPendingText(
    String channelId,
    Iterable<ChatMessage> history,
  ) {
    final confirmed = history
        .where((message) => message.sendStatus == null)
        .toList();
    final confirmedIds = confirmed
        .map((message) => message.clientMessageId)
        .toSet();
    final combined = [
      ...confirmed,
      ...pendingTextSends.values.where(
        (message) =>
            message.channelId == channelId &&
            !confirmedIds.contains(message.clientMessageId),
      ),
    ];
    combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return combined;
  }
}
