import 'dart:convert';

import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/core/http/api_failure.dart';
import 'package:boohtacord_desktop/src/features/session/authentication/api.dart';
import 'package:boohtacord_desktop/src/features/workspace/topology/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'feature authorization failure invalidates the shared session once',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=expired',
      });
      var unauthorized = 0;
      final transport = ApiTransport(
        client: MockClient((_) async => http.Response('', 401)),
      );
      transport.session.onUnauthorized = () => unauthorized++;
      await expectLater(
        TopologyApi(transport).topology(),
        throwsA(isA<ApiFailure>()),
      );
      expect(await transport.session.readCookie(), isNull);
      expect(unauthorized, 1);
      expect(await AuthSessionApi(transport).currentSession(), isNull);
      expect(unauthorized, 1);
    },
  );

  test(
    'feature APIs share one transport and the updated session cookie',
    () async {
      final requests = <http.Request>[];
      final transport = ApiTransport(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
              '',
              204,
              headers: {'set-cookie': 'session=shared; Secure; HttpOnly'},
            );
          }
          return http.Response(
            jsonEncode({'revision': 1, 'categories': []}),
            200,
          );
        }),
      );
      await AuthSessionApi(transport)
          .authenticate('member', 'password', register: false);
      await TopologyApi(transport).topology();
      expect(requests.length, 2);
      expect(requests.last.headers['cookie'], 'session=shared');
      expect(requests.last.headers['origin'], 'https://v.bootybay.ru');
    },
  );
}
