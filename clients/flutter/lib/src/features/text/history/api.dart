import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class TextHistoryApi {
  TextHistoryApi(this.transport);
  final ApiTransport transport;

  Future<List<ChatMessage>> messages(String channelId) async {
    return (await messagePage(channelId)).messages;
  }

  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) async {
    if (before != null && at != null) {
      throw const ApiFailure('Выберите один курсор истории.');
    }
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/channels/$channelId/messages', {
          'before': ?before,
          'at': ?at,
          if (at != null) 'limit': '20',
        }),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    final values = (data['messages'] as List<dynamic>)
        .map((value) => ChatMessage.fromJson(value as Map<String, dynamic>))
        .toList();
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ChatMessagePage(
      messages: values,
      nextCursor: data['next_cursor'] as String?,
    );
  }
}
