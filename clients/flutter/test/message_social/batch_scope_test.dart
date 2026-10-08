import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/conversation/reactions/batch.dart';

const channel = '11111111-1111-4111-8111-111111111111',
    message = '22222222-2222-4222-8222-222222222222';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'native metadata batches deduplicate and cap TEXT/DM requests separately',
    () async {
      final requests = <http.Request>[];
      final transport = ApiTransport(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({'reactions': [], 'can_pin': false}),
            200,
          );
        }),
      );
      final batch = ReactionBatch.forTransport(transport);
      final tasks = [
        for (var index = 0; index < 101; index++)
          batch.read(
            false,
            channel,
            '44444444-4444-4444-8444-${index.toString().padLeft(12, '0')}',
          ),
        batch.read(true, channel, message),
      ];
      await Future.wait(tasks);
      expect(requests.length, 3);
      expect(
        requests.every(
          (r) => r.url.queryParameters['message_ids']!.split(',').length <= 100,
        ),
        isTrue,
      );
      expect(
        requests.where((r) => r.url.path.contains('direct-messages')).length,
        1,
      );
    },
  );
  test('closed account or changed deployment rejects scheduled metadata before HTTP', () async {
    for (final close in [true, false]) {
      var requests = 0;
      final transport = ApiTransport(
        client: MockClient((_) async {
          requests++;
          return http.Response('', 500);
        }),
      );
      final pending = ReactionBatch.forTransport(transport)
          .read(false, channel, message);
      final asserted = expectLater(pending, throwsA(isA<Exception>()));
      if (close) {
        transport.session.scope.close();
      } else {
        transport.session.baseUrl = 'https://other.example/api/v1';
      }
      await asserted;
      expect(requests, 0);
    }
  });
}
