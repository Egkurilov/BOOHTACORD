import '../native_bindings.dart';

Future<bool> workspaceConfirmDelete(BuildContext context) async =>
    await showConfirmationDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text(
          'Текст будет заменён отметкой об удалении. Отменить это действие нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: GcColors.danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    ) ??
    false;
