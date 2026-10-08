import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/admin/voice_timeout/model.dart';

const account = '11111111-1111-4111-8111-111111111111';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443':
          'session=synthetic',
    }),
  );
  test(
    'facade uses secure scoped current-state and explicit admin desired state',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'active': false,
              'revoked_leases': 3,
              'revocation_pending': true,
            }),
            request.method == 'PUT' ? 202 : 200,
          );
        }),
      );
      await api.getVoiceTimeout(account);
      final result = await api.setVoiceTimeout(
        account,
        VoiceTimeoutInput(
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
          VoiceTimeoutReason.disruption,
        ),
      );
      await api.clearVoiceTimeout(account);
      expect(result.revocationPending, true);
      expect(requests.map((r) => r.method), ['GET', 'PUT', 'DELETE']);
      expect(
        requests.first.url.path,
        '/api/v1/accounts/$account/voice-timeout',
      );
      for (final request in requests) {
        expect(request.headers['cookie'], 'session=synthetic');
        expect(request.headers['origin'], 'https://v.bootybay.ru');
      }
      expect(
        requests[1].url.path,
        '/api/v1/admin/accounts/$account/voice-timeout',
      );
      expect(jsonDecode(requests[1].body)['reason_code'], 'DISRUPTION');
      expect(requests.last.body, isEmpty);
    },
  );
  test('invalid account and expiry are rejected before HTTP', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      api.getVoiceTimeout('foreign/path'),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      api.setVoiceTimeout(
        account,
        VoiceTimeoutInput(DateTime.now().toUtc(), VoiceTimeoutReason.other),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(calls, 0);
  });
}
