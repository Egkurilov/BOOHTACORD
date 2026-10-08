import 'dart:convert';

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import 'model.dart';

class AdminVoiceTimeoutApi {
  AdminVoiceTimeoutApi(this.transport);
  final ApiTransport transport;
  Future<VoiceTimeoutState> request(
    String account,
    String method, {
    VoiceTimeoutInput? input,
  }) => transport.run(() async {
    if (!voiceTimeoutAccount(account)) {
      throw ArgumentError('Выберите участника.');
    }
    final body = input?.toJson();
    if (!{'GET', 'PUT', 'DELETE'}.contains(method) ||
        (method == 'PUT') != (input != null)) {
      throw ArgumentError('Некорректное действие.');
    }
    final uri = transport.uri(
          '${method == 'GET' ? '' : '/admin'}/accounts/$account/voice-timeout',
        ),
        headers = await transport.headers(jsonBody: method == 'PUT');
    final response = switch (method) {
      'GET' => await transport.client.get(uri, headers: headers),
      'PUT' => await transport.client.put(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ),
      _ => await transport.client.delete(uri, headers: headers),
    };
    final data = await transport.checked(response);
    if (response.statusCode != (method == 'PUT' ? 202 : 200)) {
      throw const ApiFailure('Обновите состояние ограничения перед повтором.');
    }
    return VoiceTimeoutState.parse(data);
  });
}
