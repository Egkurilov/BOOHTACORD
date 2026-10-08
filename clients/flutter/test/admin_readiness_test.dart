import 'dart:convert';

import 'package:boohtacord_desktop/src/features/admin/readiness/model.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

Map<String, dynamic> _payload({String status = 'ready'}) => {
  'status': status,
  'checked_at': '2026-10-07T10:00:00Z',
  'database': {
    'status': 'ready',
    'reason': null,
    'sampled_at': '2026-10-07T09:59:59Z',
    'pending_revocations': 2,
    'available_bytes': null,
    'total_bytes': null,
    'reserved_bytes': null,
    'protected_bytes': null,
    'headroom_bytes': null,
  },
  'sfu': {
    'status': status == 'ready' ? 'ready' : 'failed',
    'reason': status == 'ready' ? null : 'LiveKit недоступен',
    'sampled_at': '2026-10-07T09:59:58Z',
    'pending_revocations': null,
    'available_bytes': null,
    'total_bytes': null,
    'reserved_bytes': null,
    'protected_bytes': null,
    'headroom_bytes': null,
  },
  'storage': {
    'status': 'ready',
    'reason': null,
    'sampled_at': '2026-10-07T09:59:57Z',
    'pending_revocations': null,
    'available_bytes': 1024 * 1024 * 3,
    'total_bytes': 1024 * 1024 * 10,
    'reserved_bytes': 1024,
    'protected_bytes': 2048,
    'headroom_bytes': 1024 * 1024 * 2,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=readiness-test',
    });
  });

  test('parses ready and degraded readiness responses', () {
    final ready = AdminReadiness.fromJson(_payload());
    expect(ready.status, 'ready');
    expect(ready.storage.headroomBytes, 1024 * 1024 * 2);
    expect(ready.hasFailedProbe, isFalse);

    final degraded = AdminReadiness.fromJson(_payload(status: 'degraded'));
    expect(degraded.status, 'degraded');
    expect(degraded.hasFailedProbe, isTrue);
  });

  test('marks a result stale after fifteen seconds', () {
    final result = AdminReadiness.fromJson(_payload());
    expect(result.isStaleAt(DateTime.utc(2026, 10, 7, 10, 0, 15)), isFalse);
    expect(result.isStaleAt(DateTime.utc(2026, 10, 7, 10, 0, 16)), isTrue);
  });

  test('accepts a valid degraded 503 response', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(_payload(status: 'degraded'))),
          503,
        ),
      ),
    );

    final result = await api.inspectAdminReadiness();
    expect(result.status, 'degraded');
    expect(result.sfu.status, 'failed');
  });

  test('rejects malformed readiness payloads', () {
    expect(
      () => AdminReadiness.fromJson({..._payload(), 'checked_at': 42}),
      throwsFormatException,
    );
    expect(
      () => AdminReadiness.fromJson({
        ..._payload(),
        'storage': {
          ..._payload()['storage'] as Map<String, dynamic>,
          'available_bytes': -1,
        },
      }),
      throwsFormatException,
    );
  });
}
