import 'dart:async';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('server A to B to A does not revive an old login response', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = ApiClient(
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    final rejected = expectLater(
      api.authenticate('member', 'password', register: false),
      throwsA(isA<ApiFailure>()),
    );
    await started.future;
    final original = api.baseUrl;
    api.baseUrl = 'https://other.example/api/v1';
    api.baseUrl = original;
    await api.transport.session.writeCookie('session=new');
    response.complete(
      http.Response('', 204, headers: {'set-cookie': 'session=old'}),
    );
    await rejected;
    expect(await api.transport.session.readCookie(), 'session=new');
  });
}
