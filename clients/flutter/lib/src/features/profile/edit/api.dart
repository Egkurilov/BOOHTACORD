import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/transport.dart';

class OwnProfileApi {
  OwnProfileApi(this.transport);
  final ApiTransport transport;

  Future<OwnProfile> ownProfile() async {
    final data = await transport.checked(
      await transport.client.get(
        transport.uri('/me'),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    return OwnProfile.fromJson(data);
  }

  Future<OwnProfile> updateOwnProfile(String displayName) async {
    final data = await transport.checked(
      await transport.client.patch(
        transport.uri('/me'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'display_name': displayName}),
      ),
    ) as Map<String, dynamic>;
    return OwnProfile.fromJson(data);
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await transport.checked(
      await transport.client.post(
        transport.uri('/me/password'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ),
    );
  }
}
