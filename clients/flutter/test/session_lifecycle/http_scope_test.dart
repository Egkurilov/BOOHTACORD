import 'dart:async';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('old login response cannot overwrite a replacement cookie', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = ApiClient(
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    final operation = api.authenticate('member', 'password', register: false);
    final rejected = expectLater(operation, throwsA(isA<ApiFailure>()));
    await started.future;
    api.transport.session.scope.close();
    api.transport.session.scope.begin();
    await api.transport.session.writeCookie('session=new');
    response.complete(
      http.Response('', 204, headers: {'set-cookie': 'session=old; Secure'}),
    );
    await rejected;
    expect(await api.transport.session.readCookie(), 'session=new');
  });

  test('old unauthorized response cannot expire the new account', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    var unauthorized = 0;
    final api = ApiClient(
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    api.onUnauthorized = () => unauthorized++;
    final rejected = expectLater(api.topology(), throwsA(isA<ApiFailure>()));
    await started.future;
    api.transport.session.scope.begin();
    await api.transport.session.writeCookie('session=new');
    response.complete(http.Response('', 401));
    await rejected;
    expect(unauthorized, 0);
    expect(await api.transport.session.readCookie(), 'session=new');
  });

  test('closed scope rejects new private requests before sending', () async {
    var sends = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        sends++;
        return http.Response('{}', 200);
      }),
    );
    api.transport.session.scope.close();
    await expectLater(api.topology(), throwsA(isA<ApiFailure>()));
    expect(sends, 0);
  });
}
