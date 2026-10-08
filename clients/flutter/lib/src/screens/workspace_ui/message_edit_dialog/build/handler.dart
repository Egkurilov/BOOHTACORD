import '../../mention_picker/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMessageEditDialogStateBuildBinding
    on WorkspaceMessageEditDialogStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceMessageEditDialogStateBuild(context);
  }
}

extension WorkspaceMessageEditDialogStateBuildAction
    on WorkspaceMessageEditDialogStateContext {
  Widget executeWorkspaceMessageEditDialogStateBuild(BuildContext context) =>
      AlertDialog(
        title: const Text('Изменить сообщение'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: workspaceController,
                autofocus: true,
                enabled: !workspacePending,
                maxLength: 8000,
                minLines: 2,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Изменённый текст сообщения',
                ),
              ),
              WorkspaceMentionPicker(
                options: widget.mentionOptions,
                selfId: widget.selfId,
                selectedIds: workspaceMentionIds,
                disabled: workspacePending,
                onChanged: (ids) => workspaceMutateView(() {
                  workspaceMentionIds
                    ..clear()
                    ..addAll(ids);
                }),
              ),
              if (workspaceError != null)
                Text(
                  workspaceError!,
                  style: const TextStyle(color: GcColors.danger),
                ),
              if (workspaceNotice != null)
                Text(
                  workspaceNotice!,
                  style: const TextStyle(color: GcColors.muted),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: workspacePending ? null : () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          if (workspaceNeedsRefresh)
            TextButton(
              onPressed: workspacePending ? null : workspaceRefresh,
              child: const Text('Обновить версию'),
            ),
          FilledButton(
            onPressed: workspacePending || workspaceNeedsRefresh
                ? null
                : workspaceSave,
            child: Text(workspacePending ? 'Обрабатываем…' : 'Сохранить'),
          ),
        ],
      );
}
