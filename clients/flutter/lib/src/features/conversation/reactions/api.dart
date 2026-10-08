import '../../../core/http/transport.dart';
import '../../../core/http/api_failure.dart';
import 'model.dart';

class ReactionApi {
  ReactionApi(this.transport);
  final ApiTransport transport;
  String path(bool direct, String conversation) {
    if (!socialUuid(conversation)) {
      throw const ApiFailure('Некорректная беседа.');
    }
    return '/${direct ? 'direct-messages' : 'channels'}/${Uri.encodeComponent(conversation)}';
  }

  Future<ReactionPage> read(
    bool direct,
    String conversation,
    List<String> ids,
  ) => transport.run(() async {
    final base = path(direct, conversation);
    if (ids.isEmpty || ids.length > 100 || !ids.every(socialUuid)) {
      throw const ApiFailure('Некорректные сообщения.');
    }
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('$base/message-reactions', {
          'message_ids': ids.join(','),
        }),
        headers: await transport.headers(),
      ),
    );
    return ReactionPage.parse(data, direct, ids.toSet());
  });
  Future<void> set(
    bool direct,
    String conversation,
    String message,
    String emoji,
    bool present,
  ) => transport.run(() async {
    final base = path(direct, conversation);
    if (!socialUuid(message) || !reactionEmojis.contains(emoji)) {
      throw const ApiFailure('Некорректная реакция.');
    }
    final uri = transport.uri(
          '$base/messages/${Uri.encodeComponent(message)}/reactions/${Uri.encodeComponent(emoji)}',
        ),
        headers = await transport.headers();
    final response = present
        ? await transport.client.put(uri, headers: headers)
        : await transport.client.delete(uri, headers: headers);
    await transport.checked(response);
    if (response.statusCode != 204) {
      throw const ApiFailure('Обновите состояние реакции перед повтором.');
    }
  });
}
