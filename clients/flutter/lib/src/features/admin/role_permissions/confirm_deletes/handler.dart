import '../native_bindings.dart';
import '../../confirmation/dialog.dart';
import '../lifecycle/context.dart';

extension RoleConfirmDeletesAction on RolePermissionsContext {
  Future<bool> executeConfirmDeletes() async =>
      await showConfirmationDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('Выдать права удаления?'),
          content: const Text(
            'Участники смогут удалять объекты гильдии во всех каналах.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Выдать'),
            ),
          ],
        ),
      ) ??
      false;
}
