import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requests the direct Android selector without a session cookie', () async {
    late http.Request captured;
    final api = UpdateApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"application_family":"boohtacord","catalog_revision":1,"platform":"android","distribution":"direct","channel":"stable","arch":"arm64","state":"unconfigured","target":null}', 200, headers:{'content-type':'application/json'});
      }),
      baseUrl: () => 'https://example.test',
    );
    final policy = await api.fetch(const UpdateSelector.android('arm64'));
    expect(policy.state, UpdatePolicyState.unconfigured);
    expect(captured.url.queryParameters['platform'], 'android');
    expect(captured.headers.containsKey('cookie'), isFalse);
  });
}
