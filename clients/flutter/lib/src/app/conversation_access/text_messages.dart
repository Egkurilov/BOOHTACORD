import '../../features/conversation/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppTextMessagesAccess on AppOwners {
  List<ChatMessage> get messages => conversation.messages;

  set messages(List<ChatMessage> value) => conversation.messages = value;

  String? get nextMessageCursor => conversation.nextMessageCursor;

  set nextMessageCursor(String? value) =>
      conversation.nextMessageCursor = value;

  bool get loadingOlderMessages => conversation.loadingOlderMessages;

  set loadingOlderMessages(bool value) =>
      conversation.loadingOlderMessages = value;

  bool get loadingMessages => conversation.loadingMessages;

  set loadingMessages(bool value) => conversation.loadingMessages = value;

  bool get sending => conversation.sending;

  set sending(bool value) => conversation.sending = value;

  Future<bool> loadOlderMessages() => conversation.loadOlderMessages();

  Future<void> refreshSelectedTextHistory() =>
      conversation.refreshSelectedTextHistory();

  Future<void> markTextChannelRead(String channelId, String messageId) =>
      conversation.markTextChannelRead(channelId, messageId);

  Future<bool> send(
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<MessageAttachment> attachments = const [],
  }) => conversation.send(
    body,
    replyToId: replyToId,
    mentionUserIds: mentionUserIds,
    attachments: attachments,
  );

  Future<bool> retryTextSend(String clientMessageId) =>
      conversation.retryTextSend(clientMessageId);

  Future<bool> editText(ChatMessage message, String body) =>
      conversation.editText(message, body);

  Future<MessageEditOutcome> editTextWithResult(
    ChatMessage message,
    String body,
    int expectedRevision, {
    List<String>? mentionUserIds,
  }) => conversation.editTextWithResult(
    message,
    body,
    expectedRevision,
    mentionUserIds: mentionUserIds,
  );

  Future<ChatMessage?> refreshTextMessageRevision(ChatMessage message) =>
      conversation.refreshTextMessageRevision(message);

  Future<void> deleteText(ChatMessage message) =>
      conversation.deleteText(message);
}
