import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class SearchMessagesApi {
  SearchMessagesApi(this.transport);
  final ApiTransport transport;

  Future<SearchMessagePage> searchMessages(
    String query, {
    String? channelId,
    String? directMessageId,
    String? before,
    int limit = 20,
  }) async {
    if (channelId != null && directMessageId != null) {
      throw const ApiFailure('Выберите один фильтр беседы.');
    }
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/search/messages', {
          'query': query,
          'channel_id': ?channelId,
          'direct_message_id': ?directMessageId,
          'before': ?before,
          'limit': '$limit',
        }),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    final rawMessages = data['messages'];
    if (rawMessages is! List) {
      throw const ApiFailure('Сервер вернул некорректные результаты поиска.');
    }
    final cursor = data['next_cursor'];
    if (cursor != null &&
        (cursor is! String || cursor.isEmpty || cursor.length > 512)) {
      throw const ApiFailure('Сервер вернул некорректные результаты поиска.');
    }
    return SearchMessagePage(
      messages: rawMessages
          .map((value) => SearchMessage.fromJson(value as Map<String, dynamic>))
          .toList(growable: false),
      nextCursor: cursor as String?,
    );
  }
}
