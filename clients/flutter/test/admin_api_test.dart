import 'dart:convert';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=admin-test',
    });
  });

  test('creates a category through the authenticated admin contract', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response('{}', 201);
      }),
    );

    await api.createCategory(' Игры ');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/admin/categories');
    expect(jsonDecode(request.body), {'name': ' Игры '});
    expect(request.headers['cookie'], 'session=admin-test');
    expect(request.headers['origin'], 'https://v.bootybay.ru');
  });

  test(
    'creates a channel with the selected category and web kind value',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response('{}', 201);
        }),
      );

      await api.createChannel(
        categoryId: 'cat/one',
        name: 'Общий',
        kind: ChannelKind.text,
      );

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/admin/categories/cat%2Fone/channels');
      expect(jsonDecode(request.body), {'name': 'Общий', 'kind': 'TEXT'});
    },
  );

  test('rejects invalid names before making an admin request', () async {
    var requestCount = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 201);
      }),
    );

    await expectLater(api.createCategory('  '), throwsA(isA<ApiFailure>()));
    await expectLater(
      api.createChannel(
        categoryId: 'cat',
        name: '😀' * 81,
        kind: ChannelKind.voice,
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(requestCount, 0);
  });

  test(
    'renames categories/channels and deletes only at the expected revision',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );

      await api.renameCategory(
        categoryId: 'category-1',
        name: 'Игры',
        expectedRevision: 12,
      );
      await api.renameChannel(
        channelId: 'channel-1',
        name: 'Общий',
        expectedRevision: 13,
      );
      await api.deleteEmptyCategory(
        categoryId: 'category-1',
        expectedRevision: 14,
      );

      expect(requests.map((request) => request.method), [
        'PATCH',
        'PATCH',
        'DELETE',
      ]);
      expect(requests[0].url.path, '/api/v1/admin/categories/category-1');
      expect(jsonDecode(requests[0].body), {
        'name': 'Игры',
        'expected_revision': 12,
      });
      expect(requests[1].url.path, '/api/v1/admin/channels/channel-1');
      expect(jsonDecode(requests[1].body), {
        'name': 'Общий',
        'expected_revision': 13,
      });
      expect(requests[2].url.queryParameters['expected_revision'], '14');
    },
  );

  test(
    'updates a channel description with the expected topology revision',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response.bytes(
            utf8.encode(
              '{"id":"channel/one","description":"Общение на любые темы","revision":15}',
            ),
            200,
          );
        }),
      );

      await api.updateChannelDescription(
        channelId: 'channel/one',
        description: 'Общение на любые темы',
        expectedRevision: 14,
      );

      expect(request.method, 'PATCH');
      expect(
        request.url.path,
        '/api/v1/admin/channels/channel%2Fone/description',
      );
      expect(jsonDecode(request.body), {
        'description': 'Общение на любые темы',
        'expected_revision': 14,
      });
    },
  );

  test(
    'rejects an oversized channel description before making a request',
    () async {
      var requestCount = 0;
      final api = ApiClient(
        client: MockClient((_) async {
          requestCount++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        api.updateChannelDescription(
          channelId: 'channel-1',
          description: '😀' * 201,
          expectedRevision: 1,
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(requestCount, 0);
    },
  );

  test(
    'preserves conflict status for topology recovery in the admin screen',
    () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              '{"error":{"code":"REVISION_CONFLICT","message":"Обновите список"}}',
            ),
            409,
          ),
        ),
      );

      await expectLater(
        api.renameCategory(
          categoryId: 'category-1',
          name: 'Игры',
          expectedRevision: 1,
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.status, 'status', 409)
              .having((failure) => failure.code, 'code', 'REVISION_CONFLICT'),
        ),
      );
    },
  );

  test(
    'orders categories/channels and moves channels with topology revision',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );

      await api.reorderCategories(
        categoryIds: ['category-a', 'category-b'],
        expectedRevision: 20,
      );
      await api.reorderChannels(
        categoryId: 'category-a',
        channelIds: ['channel-a', 'channel-b'],
        expectedRevision: 21,
      );
      await api.moveChannel(
        channelId: 'channel-a',
        categoryId: 'category-b',
        expectedRevision: 22,
      );

      expect(requests.map((request) => request.method), [
        'PUT',
        'PUT',
        'PATCH',
      ]);
      expect(requests[0].url.path, '/api/v1/admin/categories/order');
      expect(jsonDecode(requests[0].body), {
        'expected_revision': 20,
        'ids': ['category-a', 'category-b'],
      });
      expect(
        requests[1].url.path,
        '/api/v1/admin/categories/category-a/channels/order',
      );
      expect(jsonDecode(requests[1].body), {
        'expected_revision': 21,
        'ids': ['channel-a', 'channel-b'],
      });
      expect(requests[2].url.path, '/api/v1/admin/channels/channel-a/category');
      expect(jsonDecode(requests[2].body), {
        'category_id': 'category-b',
        'expected_revision': 22,
      });
    },
  );

  test('rejects ambiguous category order lists before sending', () async {
    var requests = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      api.reorderCategories(
        categoryIds: ['category-a', 'category-a'],
        expectedRevision: 1,
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(requests, 0);
  });

  test(
    'archives text and closes voice admission with distinct contracts',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/close-admission')) {
            return http.Response(
              '{"id":"voice-1","revision":9,"revoked_leases":2}',
              200,
            );
          }
          return http.Response('{"id":"text-1","revision":8}', 200);
        }),
      );

      await api.archiveTextChannel(channelId: 'text-1', expectedRevision: 7);
      final closed = await api.closeVoiceAdmission(
        channelId: 'voice-1',
        expectedRevision: 8,
      );

      expect(requests[0].method, 'DELETE');
      expect(requests[0].url.path, '/api/v1/admin/channels/text-1');
      expect(jsonDecode(requests[0].body), {
        'expected_revision': 7,
        'confirm_archive': true,
      });
      expect(requests[1].method, 'POST');
      expect(
        requests[1].url.path,
        '/api/v1/admin/voice-channels/voice-1/close-admission',
      );
      expect(jsonDecode(requests[1].body), {'expected_revision': 8});
      expect(closed.channelId, 'voice-1');
      expect(closed.revision, 9);
      expect(closed.revokedLeases, 2);
    },
  );

  test('loads an audit page with an opaque cursor', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response(
          '{"events":[{"id":"event-1","event_type":"CHANNEL_CREATED","created_at":"2026-09-26T10:00:00Z","actor_user_id":"account-1","actor_display_name":"Admin","actor_login":"admin"}],"next_cursor":"cursor-2"}',
          200,
        );
      }),
    );

    final page = await api.listAdminAudit(before: 'cursor-1');

    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/admin/audit');
    expect(request.url.queryParameters, {'limit': '100', 'before': 'cursor-1'});
    expect(page.events, hasLength(1));
    expect(page.events.single.eventType, 'CHANNEL_CREATED');
    expect(page.events.single.actorLogin, 'admin');
    expect(page.nextCursor, 'cursor-2');
  });

  test(
    'uses session-scoped admin directory, update, reset and voice-kick APIs',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/v1/admin/accounts') {
            return http.Response(
              '{"accounts":[{"account_id":"account-2","login":"peer","display_name":"Peer","role":"MEMBER","blocked":false,"created_at":"2026-09-01T00:00:00Z","updated_at":"2026-09-26T11:00:00Z"}],"next_cursor":"cursor-2"}',
              200,
            );
          }
          if (request.url.path == '/api/v1/admin/password-reset-links') {
            return http.Response(
              '{"url":"https://example.invalid/reset#token=one-time","expires_at":"2026-09-26T12:00:00Z"}',
              201,
            );
          }
          if (request.url.path.endsWith('/voice-kick')) {
            return http.Response('{"revoked_leases":1}', 200);
          }
          return http.Response('', 204);
        }),
      );

      final page = await api.listAdminAccounts(cursor: 'cursor-1');
      await api.updateAdminAccount(
        accountId: 'account-2',
        role: 'ADMINISTRATOR',
        blocked: true,
        expectedUpdatedAt: DateTime.utc(2026, 9, 26, 11),
      );
      final reset = await api.createAdminPasswordResetLink('account-2');
      final kicked = await api.kickAdminVoiceParticipant('account-2');

      expect(page.accounts.single.displayName, 'Peer');
      expect(
        page.accounts.single.updatedAt,
        DateTime.utc(2026, 9, 26, 11).toLocal(),
      );
      expect(page.nextCursor, 'cursor-2');
      expect(requests[0].url.queryParameters, {
        'limit': '100',
        'cursor': 'cursor-1',
      });
      expect(jsonDecode(requests[1].body), {
        'role': 'ADMINISTRATOR',
        'blocked': true,
        'expected_updated_at': '2026-09-26T11:00:00.000Z',
      });
      expect(jsonDecode(requests[2].body), {'account_id': 'account-2'});
      expect(reset.url, contains('token=one-time'));
      expect(requests[3].method, 'POST');
      expect(kicked, 1);
    },
  );

  test(
    'loads anonymous recent screen metrics from the admin contract',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response(
            '{"samples":[{"sampled_at_utc":"2026-09-29T18:30:00Z","report":{"platform":"android_native","direction":"receiver","state":"playing","frame_width":540,"frame_height":1170,"decoded_fps":14.5,"presented_fps":12,"bitrate_kbps":109.5,"jitter_ms":4,"packets_lost":2,"dropped_frames":1,"rtt_ms":36}}]}',
            200,
          );
        }),
      );

      final samples = await api.listAdminScreenMetrics();

      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/admin/screen-metrics');
      expect(request.headers['cache-control'], 'no-store');
      expect(request.headers['cookie'], 'session=admin-test');
      expect(samples, hasLength(1));
      expect(samples.single.platform, 'android_native');
      expect(samples.single.direction, 'receiver');
      expect(samples.single.frameWidth, 540);
      expect(samples.single.frameHeight, 1170);
      expect(samples.single.decodedFps, 14.5);
      expect(samples.single.presentedFps, 12);
      expect(samples.single.rttMs, 36);
    },
  );

  test('rejects malformed or excessive admin screen metrics', () async {
    final invalid = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"samples":[{"sampled_at_utc":"2026-09-29T18:30:00Z","report":{"platform":"android_native","direction":"receiver","state":"playing","frame_width":540}}]}',
          200,
        ),
      ),
    );
    await expectLater(
      invalid.listAdminScreenMetrics(),
      throwsA(isA<ApiFailure>()),
    );

    final excessive = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"samples":[${List.filled(17, '{}').join(',')}]}',
          200,
        ),
      ),
    );
    await expectLater(
      excessive.listAdminScreenMetrics(),
      throwsA(isA<ApiFailure>()),
    );
  });
}
