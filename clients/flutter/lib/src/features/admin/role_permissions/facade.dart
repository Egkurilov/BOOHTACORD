import '../../../core/http/facade_base.dart';
import '../../authorization/permissions/model.dart';
import 'api.dart';
import 'model.dart';

mixin RolePermissionsFacade on ApiFacadeBase {
  late final _rolePermissions = RolePermissionsApi(transport);
  Future<RolePolicyPage> loadRolePolicies() =>
      transport.run(_rolePermissions.load);
  Future<void> saveMemberRolePolicy({
    required int revision,
    required Map<GuildPermission, bool> values,
    required bool confirmDeleteGrants,
  }) => transport.run(
    () => _rolePermissions.saveMember(
      revision: revision,
      values: values,
      confirmDeleteGrants: confirmDeleteGrants,
    ),
  );
}
