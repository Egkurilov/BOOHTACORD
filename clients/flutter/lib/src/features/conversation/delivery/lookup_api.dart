import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import '../../../models.dart';
import '../../text/history/api.dart';
import '../../direct/history/api.dart';

class DeliveryLookupApi {
  DeliveryLookupApi(this.transport);
  final ApiTransport transport;
  Future<String?> receipt(
    bool direct,
    String conversation,
    String client,
    String owner,
  ) async {
    final path = direct ? 'direct-messages' : 'channels';
    final data = await transport.checked(
      await transport.client.get(
        transport.uri(
          '/$path/${Uri.encodeComponent(conversation)}/message-delivery/${Uri.encodeComponent(client)}',
        ),
        headers: {...await transport.headers(), 'cache-control': 'no-store'},
      ),
    ) as Map<String, dynamic>;
    if (data['account_id'] != owner) {
      throw const ApiFailure(
        'Аккаунт изменился. Повторная отправка остановлена.',
        status: 409,
        code: 'SESSION_ACCOUNT_CHANGED',
      );
    }
    if (!data.containsKey('message_id')) {
      throw const FormatException('Invalid delivery receipt.');
    }
    return data['message_id'] as String?;
  }

  Future<ChatMessage?> text(
    String conversation,
    String client,
    String owner,
  ) async {
    final id = await receipt(false, conversation, client, owner);
    if (id == null) return null;
    final page = await TextHistoryApi(transport)
        .messagePage(conversation, at: id);
    for (final row in page.messages) {
      if (row.id == id &&
          row.clientMessageId == client &&
          row.authorId == owner) {
        return row;
      }
    }
    throw const ApiFailure(
      'Сообщение сохранено. История пока недоступна; повторите проверку.',
    );
  }

  Future<DirectChatMessage?> direct(
    String conversation,
    String client,
    String owner,
  ) async {
    final id = await receipt(true, conversation, client, owner);
    if (id == null) return null;
    final page = await DirectHistoryApi(transport)
        .directMessageHistoryPage(conversation, at: id);
    for (final row in page.messages) {
      if (row.id == id &&
          row.clientMessageId == client &&
          row.authorId == owner) {
        return row;
      }
    }
    throw const ApiFailure(
      'Сообщение сохранено. История пока недоступна; повторите проверку.',
    );
  }
}
