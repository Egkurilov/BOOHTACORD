import 'dart:convert';

import 'package:boohtacord_desktop/src/features/profile/revision/cache.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=test',
    });
  });

  test('member revision cache busts the existing authenticated avatar route', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/avatar')) {
          return http.Response.bytes(const [137, 80, 78, 71], 200);
        }
        return http.Response(
          jsonEncode({
            'user_id': 'member-65',
            'login': 'member',
            'display_name': 'Member',
            'role': 'MEMBER',
            'presence': 'online',
            'avatar_url': '/api/v1/members/member-65/avatar',
            'profile_revision': 6,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final member = await api.memberProfile('member-65');
    final avatar = await api.avatarBytes(member.avatarUrl!);

    expect(memberProfileRevisions.memberRevision(member), 6);
    expect(avatar, const [137, 80, 78, 71]);
    expect(requests.first.url.path, '/api/v1/members/member-65');
    expect(requests.first.headers['cookie'], 'session=test');
    expect(requests.last.url.path, '/api/v1/members/member-65/avatar');
    expect(requests.last.url.queryParameters['revision'], '6');
    expect(requests.last.headers['cookie'], 'session=test');
  });
}
