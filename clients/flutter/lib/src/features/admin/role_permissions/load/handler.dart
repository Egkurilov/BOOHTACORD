import '../native_bindings.dart';
import '../lifecycle/context.dart';

extension RoleLoadAction on RolePermissionsContext {
  Future<void> executeLoadRoles({required bool reset}) async {
    mutate(() {
      loading = true;
      error = null;
      status = null;
    });
    try {
      final page = await widget.api.loadRolePolicies();
      final member = page.roles.firstWhere(
        (item) => item.role == GuildRole.member,
      );
      if (!mounted) return;
      mutate(() {
        roles = page.roles;
        revision = page.revision;
        baseline = Map.of(member.permissions);
        if (reset) draft = Map.of(member.permissions);
        if (reset) {
          conflict = false;
          conflictBefore = null;
          conflictCurrent = null;
        }
      });
    } catch (cause) {
      if (mounted) mutate(() => error = cause.toString());
    } finally {
      if (mounted) mutate(() => loading = false);
    }
  }
}
