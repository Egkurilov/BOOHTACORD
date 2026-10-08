import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RolePermissionTileAction on RolePermissionsContext {
  Widget executeRenderPermissionTile(
    Map<GuildPermission, bool> values,
    GuildPermission permission,
  ) => Material(
    color: Colors.transparent,
    child: CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(labels[permission]!),
      value: values[permission] ?? false,
      onChanged: role == GuildRole.administrator || saving
          ? null
          : (value) => mutate(() => draft[permission] = value ?? false),
    ),
  );
}
