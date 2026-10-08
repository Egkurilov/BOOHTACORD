import '../native_bindings.dart';
import '../../../../widgets/confirmation_dialog.dart';
import '../lifecycle/context.dart';

extension RoleChangeRoleAction on RolePermissionsContext {
  Future<void> executeChangeRole(GuildRole next) async {
    if (next == role) return;
    if (dirty) {
      final discard = await showConfirmationDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('Сохранить черновик?'),
          content: const Text(
            'При смене роли текущий черновик останется сохранённым локально.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Остаться'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Продолжить'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    mutate(() => role = next);
  }
}
