import 'dart:convert';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=test-session',
    });
  });

  test('loads a private avatar with the current session cookie', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response.bytes(const [137, 80, 78, 71], 200);
      }),
    );

    final bytes = await api.avatarBytes(
      '/api/v1/members/00000000-0000-4000-8000-000000000001/avatar',
    );

    expect(bytes, const [137, 80, 78, 71]);
    expect(request.url.host, 'v.bootybay.ru');
    expect(request.headers['cookie'], 'session=test-session');
    expect(request.headers['accept'], 'image/png');
  });

  test(
    'loads a member profile through the authenticated profile endpoint',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response.bytes(
            utf8.encode(
              '{"user_id":"member/one","login":"member","display_name":"Участник","role":"MEMBER","presence":"online"}',
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final member = await api.memberProfile('member/one');

      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/members/member%2Fone');
      expect(request.headers['cookie'], 'session=test-session');
      expect(member.displayName, 'Участник');
      expect(member.presence.name, 'online');
    },
  );

  test('rejects a cross-origin avatar before sending credentials', () async {
    var requested = false;
    final api = ApiClient(
      client: MockClient((_) async {
        requested = true;
        return http.Response('', 200);
      }),
    );

    await expectLater(
      api.avatarBytes(
        'https://example.test/api/v1/members/00000000-0000-4000-8000-000000000001/avatar',
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(requested, isFalse);
  });

  test('uploads avatar bytes as the declared image type', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );

    await api.uploadOwnAvatar(Uint8List.fromList([1, 2, 3]), 'image/jpeg');

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/me/avatar');
    expect(request.headers['content-type'], 'image/jpeg');
    expect(request.headers['cookie'], 'session=test-session');
    expect(request.bodyBytes, [1, 2, 3]);
  });

  test('deletes only the authenticated account avatar', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );

    await api.deleteOwnAvatar();

    expect(request.method, 'DELETE');
    expect(request.url.path, '/api/v1/me/avatar');
    expect(request.headers['cookie'], 'session=test-session');
  });

  test('keeps the session cookie when logout is not confirmed', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/logout')) {
          return http.Response('', 500);
        }
        return http.Response('{"authenticated":false}', 200);
      }),
    );

    await expectLater(api.logout(), throwsA(isA<ApiFailure>()));
    await api.currentSession();

    expect(requests.last.headers['cookie'], 'session=test-session');
  });

  test(
    'opens the public maintenance SSE stream without a session cookie',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response(
            'data: {"active":true}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );

      final response = await api.maintenanceEvents();
      expect(response.statusCode, 200);
      expect(request.url.path, '/api/v1/maintenance/events');
      expect(request.headers['accept'], 'text/event-stream');
      expect(request.headers['origin'], 'https://v.bootybay.ru');
      expect(request.headers, isNot(contains('cookie')));
      expect(
        await response.stream.bytesToString(),
        'data: {"active":true}\n\n',
      );
    },
  );

  test(
    'posts anonymous sender metrics with the authenticated origin',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response('', 204);
        }),
      );

      await api.reportScreenShareMetrics({
        'platform': 'android_native',
        'direction': 'sender',
        'state': 'playing',
        'encoded_fps': 18,
        'bitrate_kbps': 960,
        'rtt_ms': 45,
      });

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/voice/screen-metrics');
      expect(request.headers['origin'], 'https://v.bootybay.ru');
      expect(request.headers['cookie'], 'session=test-session');
      expect(request.headers['content-type'], 'application/json');
      expect(request.body, contains('"platform":"android_native"'));
      expect(request.body, isNot(contains('account')));
      expect(request.body, isNot(contains('channel')));
      expect(request.body, isNot(contains('track')));
    },
  );

  test(
    'reports unauthorized protected requests to the session owner',
    () async {
      var expired = false;
      final api = ApiClient(
        client: MockClient((_) async => http.Response('', 401)),
      )..onUnauthorized = () => expired = true;

      await expectLater(api.members(), throwsA(isA<ApiFailure>()));

      expect(expired, isTrue);
    },
  );

  test(
    'does not treat invalid login credentials as an expired session',
    () async {
      var expired = false;
      final api = ApiClient(
        client: MockClient((_) async => http.Response('', 401)),
      )..onUnauthorized = () => expired = true;

      await expectLater(
        api.authenticate('member', 'bad-password-123', register: false),
        throwsA(isA<ApiFailure>()),
      );

      expect(expired, isFalse);
    },
  );

  test('completes password reset without placing token in URL', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );

    final token = List.filled(43, 'a').join();
    await api.completePasswordReset(token, 'a long password 123');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/auth/password-reset/complete');
    expect(request.url.query, isEmpty);
    expect(request.headers['content-type'], 'application/json');
    expect(request.body, contains('"token":"$token"'));
  });

  test('advances only the selected text channel read cursor', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response(
          '{"channel_id":"channel-1","message_id":"message-1","message_created_at":"2026-09-25T10:00:00Z"}',
          200,
        );
      }),
    );

    await api.advanceTextChannelReadCursor('channel-1', 'message-1');

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/channels/channel-1/read-cursor');
    expect(request.body, '{"message_id":"message-1"}');
  });

  test('parses unread and mention counts only for text channels', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            '{"revision":1,"categories":[{"id":"category-1","name":"Основное","channels":[{"id":"text-1","name":"общий","kind":"TEXT","position":0,"admission_closed":false,"unread_count":4,"mention_count":2},{"id":"voice-1","name":"голос","kind":"VOICE","position":1,"admission_closed":false}]}]}',
          ),
          200,
        ),
      ),
    );

    final channels = (await api.topology()).categories.single.channels;

    expect(channels[0].unreadCount, 4);
    expect(channels[0].mentionCount, 2);
    expect(channels[1].unreadCount, 0);
    expect(channels[1].mentionCount, 0);
  });
}
