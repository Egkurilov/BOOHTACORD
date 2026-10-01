import 'dart:convert';

import '../../../core/http/transport.dart';

class DirectReadCursorApi {
  DirectReadCursorApi(this.transport);
  final ApiTransport transport;

  Future<void> advanceDirectMessageReadCursor(
    String directMessageId,
    String messageId,
  ) async {
    await transport.checked(
      await transport.client.put(
        transport.uri('/direct-messages/$directMessageId/read-cursor'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'message_id': messageId}),
      ),
    );
  }
}
