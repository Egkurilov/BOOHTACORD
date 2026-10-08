import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/transport.dart';
import '../revision/avatar_url.dart';
import '../revision/cache.dart';

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
    return _profile(data);
  }

  Future<OwnProfile> updateOwnProfile(String displayName) async {
    final data = await transport.checked(
      await transport.client.patch(
        transport.uri('/me'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'display_name': displayName}),
      ),
    ) as Map<String, dynamic>;
    return _profile(data);
  }

  OwnProfile _profile(Map<String, dynamic> data) {
    final revision = data['profile_revision'];
    if (revision != null) {
      if (revision is! int || revision <= 0) {
        throw const FormatException('Invalid profile revision.');
      }
    }
    final profile = OwnProfile.fromJson(
      withAvatarRevision(data, revision as int?),
    );
    if (revision != null) {
      memberProfileRevisions.recordOwn(profile, revision);
    }
    return profile;
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
