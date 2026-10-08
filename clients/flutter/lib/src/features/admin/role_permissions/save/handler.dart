import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RoleSaveAction on RolePermissionsContext {
  Future<void> executeSavePermissions() async {
    final before = Map<GuildPermission, bool>.of(baseline);
    final newDeletes = deleteKeys.any(
      (key) => baseline[key] != true && draft[key] == true,
    );
    if (newDeletes && !await confirmDeletes()) return;
    mutate(() {
      saving = true;
      error = null;
      status = null;
      conflict = false;
    });
    try {
      await widget.api.saveMemberRolePolicy(
        revision: revision,
        values: draft,
        confirmDeleteGrants: newDeletes,
      );
      await loadRoles(reset: true);
      await widget.onSaved();
      if (mounted) mutate(() => status = 'Разрешения сохранены.');
    } catch (cause) {
      if (cause is ApiFailure && cause.status == 409) {
        mutate(() {
          conflict = true;
          conflictBefore = before;
          error = 'Настройки уже изменены. Проверьте актуальные значения и решите, применять ли черновик.';
        });
        await loadRoles(reset: false);
        if (mounted) {
          mutate(() {
            conflictCurrent = Map<GuildPermission, bool>.of(baseline);
            error = 'Настройки уже изменены. Проверьте актуальные значения и решите, применять ли черновик.';
          });
        }
      } else if (mounted) {
        mutate(() => error = cause.toString());
      }
    } finally {
      if (mounted) mutate(() => saving = false);
    }
  }
}
