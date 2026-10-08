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

  test('own profile records only the server revision and busts avatar cache', () async {
    late http.Request sent;
    final api = ApiClient(
      client: MockClient((request) async {
        sent = request;
        expect(request.url.path, '/api/v1/me');
        return http.Response(
          jsonEncode({
            'account_id': 'u1',
            'login': 'login',
            'display_name': 'Name',
            'role': 'MEMBER',
            'avatar_url': '/api/v1/members/u1/avatar',
            'profile_revision': 12,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final profile = await api.ownProfile();

    expect(memberProfileRevisions.ownRevision(profile), 12);
    expect(sent.headers['cookie'], 'session=test');
    expect(Uri.parse(profile.avatarUrl!).queryParameters['revision'], '12');
  });
}
