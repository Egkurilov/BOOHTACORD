import 'dart:convert';

import '../../../core/http/transport.dart';
import '../../authorization/permissions/model.dart';
import 'model.dart';

class RolePermissionsApi {
  RolePermissionsApi(this.transport);
  final ApiTransport transport;
  Future<RolePolicyPage> load() async {
    final data = await transport.checked(await transport.client.get(transport.uri('/admin/roles'), headers: await transport.headers())) as Map<String, dynamic>;
    final revision = data['revision']; final roles = data['roles'];
    if (revision is! int || revision < 1 || roles is! List || roles.length != 2) throw const FormatException('Некорректные настройки ролей.');
    return RolePolicyPage(revision, roles.map((value) => RolePolicy.fromJson(value as Map<String, dynamic>)).toList(growable: false));
  }
  Future<void> saveMember({required int revision, required Map<GuildPermission, bool> values, required bool confirmDeleteGrants}) async {
    await transport.checked(await transport.client.put(transport.uri('/admin/roles/MEMBER/permissions'), headers: await transport.headers(jsonBody: true), body: jsonEncode({
      'expected_revision': revision,
      'permissions': {for (final entry in values.entries) entry.key.wireName: entry.value},
      'confirm_delete_grants': confirmDeleteGrants,
    })));
  }
}
