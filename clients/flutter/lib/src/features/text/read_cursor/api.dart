import 'dart:convert';

import '../../../core/http/transport.dart';

class TextReadCursorApi {
  TextReadCursorApi(this.transport);
  final ApiTransport transport;

  Future<void> advanceTextChannelReadCursor(
    String channelId,
    String messageId,
  ) async {
    await transport.checked(
      await transport.client.put(
        transport.uri('/channels/$channelId/read-cursor'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'message_id': messageId}),
      ),
    );
  }
}
