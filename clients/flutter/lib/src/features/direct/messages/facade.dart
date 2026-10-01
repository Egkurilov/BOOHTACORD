import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin DirectMessagesFacade on ApiFacadeBase {
  late final _directMessages = DirectMessagesApi(transport);

  Future<DirectChatMessage> sendDirectMessage(
    String id,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) => _directMessages.sendDirectMessage(
    id,
    clientMessageId,
    body,
    replyToId: replyToId,
    mentionUserIds: mentionUserIds,
    attachmentIds: attachmentIds,
  );

  Future<DirectChatMessage> editDirectMessage(
    String directMessageId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) => _directMessages.editDirectMessage(
    directMessageId,
    messageId,
    body,
    expectedRevision,
    mentionUserIds: mentionUserIds,
  );

  Future<void> deleteDirectMessage(String directMessageId, String messageId) =>
      _directMessages.deleteDirectMessage(directMessageId, messageId);
}
