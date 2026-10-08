import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/admin_voice_timeout/controller.dart';

const account = '11111111-1111-4111-8111-111111111111';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('apply and clear require a successful authoritative read', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    final owner = AdminVoiceTimeoutController(api, account);
    await owner.apply();
    await owner.clear();
    expect(calls, 0);
    owner.dispose();
  });
  for (final boundary in ['session', 'server', 'dispose']) {
    test(
      '$boundary boundary rejects earlier response and later mutation',
      () async {
        final response = Completer<http.Response>(),
            entered = Completer<void>();
        var calls = 0;
        final api = ApiClient(
          client: MockClient((_) async {
            calls++;
            entered.complete();
            return response.future;
          }),
        );
        final owner = AdminVoiceTimeoutController(api, account);
        final loading = owner.load();
        await entered.future;
        if (boundary == 'session') api.transport.session.scope.close();
        if (boundary == 'server') {
          api.baseUrl = 'https://different.invalid/api/v1';
        }
        if (boundary == 'dispose') owner.dispose();
        response.complete(
          http.Response(
            jsonEncode({
              'active': false,
              'revoked_leases': 0,
              'revocation_pending': false,
            }),
            200,
          ),
        );
        await loading;
        expect(owner.value, isNull);
        await owner.clear();
        expect(calls, 1);
        if (boundary != 'dispose') owner.dispose();
      },
    );
  }
}
