import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin TextMessagesFacade on ApiFacadeBase {
  late final _textMessages = TextMessagesApi(transport);

  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) => _textMessages.sendMessage(
    channelId,
    clientMessageId,
    body,
    replyToId: replyToId,
    mentionUserIds: mentionUserIds,
    attachmentIds: attachmentIds,
  );

  Future<ChatMessage> editMessage(
    String channelId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) => _textMessages.editMessage(
    channelId,
    messageId,
    body,
    expectedRevision,
    mentionUserIds: mentionUserIds,
  );

  Future<void> deleteMessage(String channelId, String messageId) =>
      _textMessages.deleteMessage(channelId, messageId);
}
