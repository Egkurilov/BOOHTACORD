import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('temporary TLS failure keeps the cookie for session retry', () async {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=example',
    });
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          throw const HandshakeException('temporary TLS failure');
        }
        return http.Response(
          jsonEncode({'account_id': 'account-1', 'role': 'MEMBER'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(api.currentSession(), throwsA(isA<HandshakeException>()));
    final restored = await api.currentSession();

    expect(restored?.accountId, 'account-1');
    expect(requests.map((request) => request.headers['cookie']), [
      'session=example',
      'session=example',
    ]);
  });
}
