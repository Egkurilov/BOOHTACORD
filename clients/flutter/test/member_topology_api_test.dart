import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

void main() {
  test('member topology mutations preserve request id and confirmations', () async {
    final requests = <http.Request>[]; const command = '11111111-1111-4111-8111-111111111111';
    final client = ApiClient(client: MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({'client_request_id': command, 'topology_revision': 8, 'result': {'resource_type': 'TEXT_CHANNEL', 'resource_id': 'channel-1', 'state': 'ACTIVE'}}), 200);
    }));
    client.baseUrl = 'https://voice.test/api/v1';
    await client.createMemberChannel('cat/one', 'Общий', ChannelKind.text, command);
    await client.archiveMemberText('channel-1', 8, command);
    expect(requests.first.url.path, '/api/v1/categories/cat%2Fone/channels');
    expect(jsonDecode(requests.first.body)['client_request_id'], command);
    expect(jsonDecode(requests.last.body), containsPair('confirm_archive', true));
  });
}
