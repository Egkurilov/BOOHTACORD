import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/conversation/reactions/api.dart';
import 'package:boohtacord_desktop/src/features/conversation/reactions/model.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    message = '22222222-2222-4222-8222-222222222222';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'six explicit reactions preserve private endpoint and empty mutation body',
    () async {
      final requests = <http.Request>[];
      final transport = ApiTransport(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
      );
      final api = ReactionApi(transport);
      for (final emoji in reactionEmojis) {
        await api.set(true, channel, message, emoji, true);
        await api.set(true, channel, message, emoji, false);
      }
      expect(requests.length, 12);
      expect(requests.map((request) => request.method).take(2), [
        'PUT',
        'DELETE',
      ]);
      expect(
        requests.every(
          (request) =>
              request.url.path.startsWith(
                '/api/v1/direct-messages/$channel/messages/$message/reactions/',
              ) &&
              request.body.isEmpty,
        ),
        isTrue,
      );
      expect(
        requests.every(
          (request) => request.headers['origin'] == 'https://v.bootybay.ru',
        ),
        isTrue,
      );
    },
  );
  test('reaction reads are bounded and reject foreign metadata or DM pin authority', () async {
    var calls = 0;
    var canPin = false;
    var target = message;
    final transport = ApiTransport(
      client: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'can_pin': canPin,
            'reactions': [
              {'message_id': target, 'emoji': '👍', 'count': 2, 'mine': true},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final api = ReactionApi(transport);
    final page = await api.read(true, channel, [message]);
    expect(page.rows.single.mine, isTrue);
    expect(page.rows.single.count, 2);
    await expectLater(
      api.read(true, channel, List.filled(101, message)),
      throwsA(isA<Exception>()),
    );
    expect(calls, 1);
    target = channel;
    await expectLater(
      api.read(true, channel, [message]),
      throwsA(isA<Exception>()),
    );
    target = message;
    canPin = true;
    await expectLater(
      api.read(true, channel, [message]),
      throwsA(isA<Exception>()),
    );
  });
}
