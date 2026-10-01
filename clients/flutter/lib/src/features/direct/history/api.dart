import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';

class DirectHistoryApi {
  DirectHistoryApi(this.transport);
  final ApiTransport transport;

  Future<List<DirectChatMessage>> directMessageHistory(String id) async {
    return (await directMessageHistoryPage(id)).messages;
  }

  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) async {
    if (before != null && at != null) {
      throw const ApiFailure('Выберите один курсор истории.');
    }
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/direct-messages/$id/messages', {
          'before': ?before,
          'at': ?at,
          if (at != null) 'limit': '20',
        }),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    final values = (data['messages'] as List<dynamic>)
        .map(
          (value) => DirectChatMessage.fromJson(value as Map<String, dynamic>),
        )
        .toList();
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return DirectChatMessagePage(
      messages: values,
      nextCursor: data['next_cursor'] as String?,
    );
  }
}
