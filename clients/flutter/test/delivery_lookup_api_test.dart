import 'dart:convert';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'caller receipt resolves through addressed history without POST',
    () async {
      final paths = <String>[];
      final api = ApiClient(
        client: MockClient((request) async {
          paths.add(request.url.toString());
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode(
              request.url.path.contains('/message-delivery/')
                  ? {'account_id': 'owner', 'message_id': 'stored'}
                  : {
                      'messages': [
                        {
                          'id': 'stored',
                          'channel_id': 'channel',
                          'author_id': 'owner',
                          'client_message_id': 'client',
                          'body': 'fixture',
                          'created_at': '2026-10-05T00:00:00Z',
                          'revision': 1,
                          'deleted': false,
                          'attachments': [],
                          'mention_user_ids': [],
                        },
                      ],
                    },
            ),
            200,
          );
        }),
      );
      final found = await api.findSentText('channel', 'client', 'owner');
      expect(found?.id, 'stored');
      expect(paths.first, contains('/message-delivery/client'));
      expect(paths.last, contains('at=stored'));
    },
  );
  test('absent receipt makes no history request', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({'account_id': 'owner', 'message_id': null}),
          200,
        );
      }),
    );
    expect(await api.findSentDirect('pair', 'client', 'owner'), isNull);
    expect(calls, 1);
  });
  test('changed cookie owner prevents history fetch', () async {
    var calls = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({'account_id': 'new-owner', 'message_id': 'stored'}),
          200,
        );
      }),
    );
    await expectLater(
      api.findSentText('channel', 'client', 'owner'),
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.code,
          'code',
          'SESSION_ACCOUNT_CHANGED',
        ),
      ),
    );
    expect(calls, 1);
  });
}
