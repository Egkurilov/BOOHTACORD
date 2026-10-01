import 'dart:io';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie': 'session=private-test',
    }),
  );

  test(
    'OTLP relay uses current session and accepts the API 202 response',
    () async {
      late http.Request sent;
      final api = ApiClient(
        client: MockClient((request) async {
          sent = request;
          return http.Response('', 202);
        }),
      );
      await api.submitClientSpans([1, 2, 3]);
      expect(sent.url.path, '/api/v1/telemetry/traces');
      expect(sent.headers['cookie'], 'session=private-test');
      expect(sent.headers['origin'], 'https://v.bootybay.ru');
      expect(sent.headers['x-client-platform'], Platform.operatingSystem);
      expect(sent.headers['content-type'], 'application/x-protobuf');
      expect(sent.bodyBytes, [1, 2, 3]);
    },
  );

  test('OTLP relay reports status without exposing response body', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response('private-upstream-detail', 401),
      ),
    );

    try {
      await api.submitClientSpans([1]);
      fail('Expected a non-202 response to fail export.');
    } on StateError catch (error) {
      expect(error.message, contains('HTTP 401'));
      expect(error.message, isNot(contains('private-upstream-detail')));
    }
  });
}
