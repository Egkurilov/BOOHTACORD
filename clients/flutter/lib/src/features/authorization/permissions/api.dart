import '../../../core/http/transport.dart';
import 'model.dart';

class PermissionsApi {
  PermissionsApi(this.transport);
  final ApiTransport transport;

  Future<PermissionSnapshot> load() async {
    final data = await transport.checked(await transport.client.get(transport.uri('/auth/permissions'), headers: await transport.headers())) as Map<String, dynamic>;
    return PermissionSnapshot.fromJson(data);
  }
}
