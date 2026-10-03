import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

Map<String, bool> values([bool deletes = false]) => {
  'channel.text.create': true, 'channel.text.delete': deletes,
  'channel.voice.create': true, 'channel.voice.delete': deletes,
  'category.create': true, 'category.delete': deletes,
};

void main() {
  test('loads effective permissions and saves a complete member policy', () async {
    final requests = <http.Request>[];
    final client = ApiClient(client: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/permissions')) return http.Response(jsonEncode({'account_id': 'user-1', 'role': 'MEMBER', 'permissions_revision': 4, 'permissions': values()}), 200);
      if (request.method == 'GET') return http.Response(jsonEncode({'revision': 4, 'roles': [
        {'role': 'ADMINISTRATOR', 'display_name': 'Администратор', 'editable': false, 'permissions': values(true)},
        {'role': 'MEMBER', 'display_name': 'Пользователь', 'editable': true, 'permissions': values()},
      ]}), 200);
      return http.Response('{}', 200);
    }));
    client.baseUrl = 'https://voice.test/api/v1';
    final snapshot = await client.loadPermissions(); final policies = await client.loadRolePolicies();
    expect(snapshot.allows(GuildPermission.textCreate), isTrue); expect(policies.revision, 4);
    await client.saveMemberRolePolicy(revision: 4, values: snapshot.values, confirmDeleteGrants: false);
    expect(jsonDecode(requests.last.body)['permissions'], values());
  });
}
