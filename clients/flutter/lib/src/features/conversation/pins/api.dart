import '../../../core/http/transport.dart';
import '../../../core/http/api_failure.dart';
import '../reactions/model.dart';
import 'model.dart';

class TextPinApi {
  TextPinApi(this.transport);
  final ApiTransport transport;
  Future<TextPinPage> read(String channel, {String? before}) =>
      transport.run(() async {
        if (!socialUuid(channel) ||
            before != null && (before.isEmpty || before.length > 256)) {
          throw const ApiFailure('Некорректные закрепления.');
        }
        final response = await transport.client.get(
          transport.uri('/channels/${Uri.encodeComponent(channel)}/pins', {
            'before': ?before,
          }),
          headers: await transport.headers(),
        );
        return TextPinPage.parse(await transport.checked(response));
      });
  Future<void> set(
    String channel,
    String message,
    bool present,
  ) => transport.run(() async {
    if (!socialUuid(channel) || !socialUuid(message)) {
      throw const ApiFailure('Некорректное закрепление.');
    }
    final uri = transport.uri(
          '/admin/text-channels/${Uri.encodeComponent(channel)}/pins/${Uri.encodeComponent(message)}',
        ),
        headers = await transport.headers();
    final response = present
        ? await transport.client.put(uri, headers: headers)
        : await transport.client.delete(uri, headers: headers);
    await transport.checked(response);
    if (response.statusCode != 204) {
      throw const ApiFailure('Обновите закрепления перед повтором.');
    }
  });
}
