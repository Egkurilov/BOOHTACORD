import 'package:boohtacord_desktop/src/features/admin/role_permissions/model.dart';
import 'package:boohtacord_desktop/src/features/authorization/permissions/model.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'admin_topology_fake_api.dart';

class RolePermissionsTestApi extends TopologyTestApi {
  int revision = 1;
  Map<GuildPermission, bool> member = _values(false);
  Map<GuildPermission, bool> administrator = _values(true);
  bool conflictOnNextSave = false;
  int? savedRevision;
  Map<GuildPermission, bool>? savedValues;
  bool? confirmedDeletes;
  int saves = 0;

  @override
  Future<RolePolicyPage> loadRolePolicies() async => RolePolicyPage(revision, [
    RolePolicy(role: GuildRole.administrator, displayName: 'Администратор',
        editable: false, permissions: Map.of(administrator)),
    RolePolicy(role: GuildRole.member, displayName: 'Пользователь',
        editable: true, permissions: Map.of(member)),
  ]);

  @override
  Future<void> saveMemberRolePolicy({
    required int revision,
    required Map<GuildPermission, bool> values,
    required bool confirmDeleteGrants,
  }) async {
    if (conflictOnNextSave) {
      conflictOnNextSave = false;
      member = Map.of(member)..[GuildPermission.categoryCreate] = true;
      this.revision++;
      throw const ApiFailure('Конфликт версии', status: 409);
    }
    savedRevision = revision;
    savedValues = Map.of(values);
    confirmedDeletes = confirmDeleteGrants;
    saves++;
    member = Map.of(values);
    this.revision++;
  }
}

Map<GuildPermission, bool> _values(bool value) => {
  for (final permission in GuildPermission.values) permission: value,
};
