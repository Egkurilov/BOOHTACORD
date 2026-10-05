import '../../../core/http/transport.dart';
import 'model.dart';

class OwnSessionsApi {
  OwnSessionsApi(this.transport);
  final ApiTransport transport;
  Future<OwnSessionPage> read([String? cursor]) async {
    final response = await transport.client.get(
      transport.uri(
        '/me/sessions',
        cursor == null ? null : {'cursor': sessionHandle(cursor)},
      ),
      headers: {...await transport.headers(), 'cache-control': 'no-store'},
    );
    return OwnSessionPage.fromJson(
      await transport.checked(response) as Map<String, dynamic>,
    );
  }

  Future<void> revoke(String owner, String id) async {
    final path = '/me/sessions/${sessionHandle(id)}';
    final headers = {
      'X-Account-ID': sessionHandle(owner),
      ...await transport.headers(),
    };
    await transport.checked(
      await transport.client.delete(transport.uri(path), headers: headers),
    );
  }

  Future<void> revokeOthers(String owner) async {
    final headers = {
      'X-Account-ID': sessionHandle(owner),
      ...await transport.headers(),
    };
    await transport.checked(
      await transport.client.post(
        transport.uri('/me/sessions/revoke-others'),
        headers: headers,
      ),
    );
  }
}
