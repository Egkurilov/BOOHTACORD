import 'dart:convert';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const owner = '00000000-0000-4000-8000-000000000001';
const handle = '00000000-0000-4000-8000-000000000002';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('session list is typed and mutations bind the viewed account', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method != 'GET') return http.Response('', 204);
        return http.Response(
          jsonEncode({
            'account_id': owner,
            'sessions': [
              {
                'id': handle,
                'label': 'Вход',
                'current': true,
                'created_at': '2026-10-05T00:00:00Z',
                'last_active_at': '2026-10-05T01:00:00Z',
                'token_digest': 'must-not-render',
              },
            ],
            'next_cursor': null,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final page = await api.ownSessions();
    expect(page.accountId, owner);
    expect(page.sessions.single.current, isTrue);
    await api.revokeOwnSession(owner, handle);
    await api.revokeOtherSessions(owner);
    expect(requests[1].method, 'DELETE');
    expect(requests[1].headers['x-account-id'], owner);
    expect(requests[2].url.path, endsWith('/revoke-others'));
    expect(requests[2].headers['x-account-id'], owner);
  });
  test('invalid handles never reach the transport', () async {
    var requests = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        requests++;
        return http.Response('', 204);
      }),
    );
    await expectLater(
      api.revokeOwnSession(owner, '../other'),
      throwsArgumentError,
    );
    expect(requests, 0);
  });
  test('account switch conflict preserves the typed failure', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'SESSION_ACCOUNT_CHANGED'},
          }),
          409,
        ),
      ),
    );
    await expectLater(
      api.revokeOtherSessions(owner),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.code,
          'code',
          'SESSION_ACCOUNT_CHANGED',
        ),
      ),
    );
  });
}
