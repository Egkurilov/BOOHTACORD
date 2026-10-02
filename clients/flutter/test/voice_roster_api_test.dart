import 'dart:convert';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie': 'session=test-session',
    });
  });

  test(
    'loads the authenticated no-store roster without joining voice',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'channels': [
                  {
                    'channel_id': 'voice-1',
                    'participants': [
                      {
                        'account_id': 'account-2',
                        'display_name': 'Мика',
                        'screen_sharing': true,
                        'microphone_muted': false,
                      },
                    ],
                  },
                  {'channel_id': 'voice-2', 'participants': []},
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final rosters = await api.voiceParticipants();

      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/voice/participants');
      expect(request.headers['cookie'], 'session=test-session');
      expect(request.headers['cache-control'], 'no-store');
      expect(rosters, hasLength(2));
      expect(rosters.first.participants.single.displayName, 'Мика');
      expect(rosters.first.participants.single.screenSharing, isTrue);
      expect(rosters.first.participants.single.microphoneMuted, isFalse);
      expect(rosters.last.participants, isEmpty);
    },
  );

  test('rejects duplicate channels and malformed roster members', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'channels': [
                {'channel_id': 'voice-1', 'participants': []},
                {'channel_id': 'voice-1', 'participants': []},
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(api.voiceParticipants(), throwsA(isA<ApiFailure>()));
  });

  test(
    'rejects a roster member without the required microphone state',
    () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'channels': [
                  {
                    'channel_id': 'voice-1',
                    'participants': [
                      {
                        'account_id': 'account-2',
                        'display_name': 'Мика',
                        'screen_sharing': false,
                      },
                    ],
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await expectLater(api.voiceParticipants(), throwsFormatException);
    },
  );

  test('reports unavailable private voice presence from the API', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'VOICE_PRESENCE_UNAVAILABLE',
                'message': 'Не удалось загрузить участников голосовых комнат',
              },
            }),
          ),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      api.voiceParticipants(),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.status, 'status', 503)
            .having(
              (failure) => failure.code,
              'code',
              'VOICE_PRESENCE_UNAVAILABLE',
            ),
      ),
    );
  });

  test(
    'expires the local session when opening an SSE stream returns 401',
    () async {
      var unauthorized = false;
      final api = ApiClient(
        client: MockClient((_) async => http.Response('unauthorized', 401)),
      )..onUnauthorized = () => unauthorized = true;

      await expectLater(api.voiceRosterEvents(), throwsA(isA<ApiFailure>()));
      expect(unauthorized, isTrue);
    },
  );
}
