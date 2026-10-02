import '../../features/conversation/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppDirectMessagesAccess on AppOwners {
  List<DirectChatMessage> get directMessageHistory =>
      conversation.directMessageHistory;

  set directMessageHistory(List<DirectChatMessage> value) =>
      conversation.directMessageHistory = value;

  String? get nextDirectMessageCursor => conversation.nextDirectMessageCursor;

  set nextDirectMessageCursor(String? value) =>
      conversation.nextDirectMessageCursor = value;

  bool get loadingOlderDirectMessages =>
      conversation.loadingOlderDirectMessages;

  set loadingOlderDirectMessages(bool value) =>
      conversation.loadingOlderDirectMessages = value;

  bool get loadingDirectMessages => conversation.loadingDirectMessages;

  set loadingDirectMessages(bool value) =>
      conversation.loadingDirectMessages = value;

  Future<bool> loadOlderDirectMessages() =>
      conversation.loadOlderDirectMessages();

  Future<void> markSelectedDirectMessageRead() =>
      conversation.markSelectedDirectMessageRead();

  Future<bool> sendDirect(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) => conversation.sendDirect(
    body,
    replyToId: replyToId,
    mentionUserIds: mentionUserIds,
    attachments: attachments,
  );

  Future<bool> editDirect(DirectChatMessage message, String body) =>
      conversation.editDirect(message, body);

  Future<MessageEditOutcome> editDirectWithResult(
    DirectChatMessage message,
    String body,
    int expectedRevision, {
    List<String>? mentionUserIds,
  }) => conversation.editDirectWithResult(
    message,
    body,
    expectedRevision,
    mentionUserIds: mentionUserIds,
  );

  Future<DirectChatMessage?> refreshDirectMessageRevision(
    DirectChatMessage message,
  ) => conversation.refreshDirectMessageRevision(message);

  Future<void> deleteDirect(DirectChatMessage message) =>
      conversation.deleteDirect(message);

  Future<bool> retryDirectSend(String clientMessageId) =>
      conversation.retryDirectSend(clientMessageId);
}
