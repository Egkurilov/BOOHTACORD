import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/transport.dart';

class TextMessagesApi {
  TextMessagesApi(this.transport);
  final ApiTransport transport;

  Future<ChatMessage> sendMessage(
    String channelId,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    final response = await transport.client.post(
      transport.uri('/channels/$channelId/messages'),
      headers: await transport.headers(jsonBody: true),
      body: jsonEncode({
        'client_message_id': clientMessageId,
        'body': body,
        'reply_to_id': ?replyToId,
        if (mentionUserIds.isNotEmpty) 'mention_user_ids': mentionUserIds,
        if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
      }),
    );
    return ChatMessage.fromJson(
      await transport.checked(response) as Map<String, dynamic>,
    );
  }

  Future<ChatMessage> editMessage(
    String channelId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    final data = await transport.checked(
      await transport.client.patch(
        transport.uri('/channels/$channelId/messages/$messageId'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'body': body,
          'expected_revision': expectedRevision,
          'mention_user_ids': mentionUserIds,
        }),
      ),
    ) as Map<String, dynamic>;
    return ChatMessage.fromJson(data);
  }

  Future<void> deleteMessage(String channelId, String messageId) async {
    await transport.checked(
      await transport.client.delete(
        transport.uri('/channels/$channelId/messages/$messageId'),
        headers: await transport.headers(),
      ),
    );
  }
}
