import 'package:boohtacord_desktop/src/features/direct/conversations/api.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  test(
    'candidate page preserves explicit cursor and reads one authorized page',
    () async {
      final calls = <Uri>[];
      final transport = ApiTransport(
        client: MockClient((request) async {
          calls.add(request.url);
          return http.Response(
            '{"candidates":[{"id":"person-1","display_name":"Guild member"}],"next_after":"opaque-next"}',
            200,
          );
        }),
      );
      final api = DirectConversationsApi(transport);
      final page = await api.candidatePage(after: 'opaque-current');
      expect(calls.length, 1);
      expect(calls.single.path, '/api/v1/direct-message-candidates');
      expect(calls.single.queryParameters, {
        'limit': '100',
        'after': 'opaque-current',
      });
      expect(page.items.single.id, 'person-1');
      expect(page.nextAfter, 'opaque-next');
    },
  );
}
