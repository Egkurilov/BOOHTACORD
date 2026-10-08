import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/conversation/pins/api.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    message = '22222222-2222-4222-8222-222222222222',
    author = '33333333-3333-4333-8333-333333333333';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'TEXT pin reader validates bounded preview and stable opaque cursor',
    () async {
      final requests = <http.Request>[];
      var preview = '<script>unsafe()</script>';
      final api = TextPinApi(
        ApiTransport(
          client: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode({
                'can_manage': false,
                'next_cursor': 'opaque-cursor',
                'pins': [
                  {
                    'message_id': message,
                    'author_id': author,
                    'preview': preview,
                    'pinned_at': '2026-10-09T12:01:00Z',
                    'message_created_at': '2026-10-09T12:00:00Z',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final page = await api.read(channel, before: 'previous-cursor');
      expect(page.pins.single.preview, preview);
      expect(page.nextCursor, 'opaque-cursor');
      expect(page.canManage, isFalse);
      expect(requests.single.url.queryParameters['before'], 'previous-cursor');
      preview = 'a' * 241;
      await expectLater(api.read(channel), throwsA(isA<Exception>()));
      await expectLater(
        api.read(channel, before: ''),
        throwsA(isA<Exception>()),
      );
      expect(requests.length, 2);
    },
  );
  test(
    'pin desired state uses administrator TEXT path and respects denial',
    () async {
      final requests = <http.Request>[];
      var status = 204;
      final api = TextPinApi(
        ApiTransport(
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('', status);
          }),
        ),
      );
      await api.set(channel, message, true);
      await api.set(channel, message, false);
      expect(requests.map((r) => r.method), ['PUT', 'DELETE']);
      expect(
        requests.every(
          (r) =>
              r.url.path ==
                  '/api/v1/admin/text-channels/$channel/pins/$message' &&
              r.body.isEmpty,
        ),
        isTrue,
      );
      status = 403;
      await expectLater(
        api.set(channel, message, true),
        throwsA(isA<Exception>()),
      );
    },
  );
}
