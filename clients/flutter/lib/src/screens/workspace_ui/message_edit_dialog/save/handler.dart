import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMessageEditDialogStateWorkspaceSaveBinding
    on WorkspaceMessageEditDialogStateContext {
  @override
  Future<void> workspaceSave() {
    return executeWorkspaceMessageEditDialogStateWorkspaceSave();
  }
}

extension WorkspaceMessageEditDialogStateWorkspaceSaveAction
    on WorkspaceMessageEditDialogStateContext {
  Future<void> executeWorkspaceMessageEditDialogStateWorkspaceSave() async {
    if (workspacePending || workspaceNeedsRefresh) return;
    final body = workspaceController.text;
    if (body.trim().isEmpty || body.trim().runes.length > 8000) {
      workspaceMutateView(
        () => workspaceError = 'Сообщение должно содержать до 8000 символов.',
      );
      return;
    }
    workspaceMutateView(() {
      workspacePending = true;
      workspaceError = null;
      workspaceNotice = null;
    });
    MessageEditOutcome outcome;
    try {
      outcome = await widget.onSave(
        body,
        workspaceRevision,
        workspaceMentionIds.toList(),
      );
    } catch (_) {
      outcome = (
        kind: MessageEditStatus.error,
        message: 'Не удалось сохранить сообщение. Повторите попытку.',
      );
    }
    if (!mounted) return;
    if (outcome.kind == MessageEditStatus.saved) {
      Navigator.pop(context);
      return;
    }
    workspaceMutateView(() {
      workspacePending = false;
      workspaceNeedsRefresh = outcome.kind == MessageEditStatus.conflict;
      workspaceError = outcome.message ?? 'Не удалось сохранить сообщение.';
    });
  }
}
