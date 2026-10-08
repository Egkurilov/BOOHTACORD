import '../native_bindings.dart';
import 'context.dart';
import '../load/handler.dart';
import '../defaults/handler.dart';
import '../save/handler.dart';
import '../confirm_deletes/handler.dart';
import '../change_role/handler.dart';
import '../permission_matrix/handler.dart';
import '../permission_tile/handler.dart';
import '../build/handler.dart';

class RolePermissionsState extends RolePermissionsContext {
  @override
  void initState() {
    super.initState();
    loadRoles(reset: true);
  }

  @override
  Future<void> loadRoles({required bool reset}) =>
      executeLoadRoles(reset: reset);
  @override
  void loadDefaults() => executeLoadDefaults();
  @override
  Future<void> savePermissions() => executeSavePermissions();
  @override
  Future<bool> confirmDeletes() => executeConfirmDeletes();
  @override
  Future<void> changeRole(GuildRole next) => executeChangeRole(next);
  @override
  Widget renderPermissionMatrix(
    Map<GuildPermission, bool> values,
    double width,
  ) => executeRenderPermissionMatrix(values, width);
  @override
  Widget renderPermissionTile(
    Map<GuildPermission, bool> values,
    GuildPermission permission,
  ) => executeRenderPermissionTile(values, permission);
  @override
  Widget build(BuildContext context) => executeBuild(context);
}
