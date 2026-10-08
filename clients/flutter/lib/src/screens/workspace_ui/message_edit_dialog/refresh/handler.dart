import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMessageEditDialogStateWorkspaceRefreshBinding
    on WorkspaceMessageEditDialogStateContext {
  @override
  Future<void> workspaceRefresh() {
    return executeWorkspaceMessageEditDialogStateWorkspaceRefresh();
  }
}

extension WorkspaceMessageEditDialogStateWorkspaceRefreshAction
    on WorkspaceMessageEditDialogStateContext {
  Future<void> executeWorkspaceMessageEditDialogStateWorkspaceRefresh() async {
    if (workspacePending || !workspaceNeedsRefresh) return;
    workspaceMutateView(() {
      workspacePending = true;
      workspaceError = null;
    });
    ({int revision, bool deleted})? latest;
    try {
      latest = await widget.onRefresh();
    } catch (_) {
      latest = null;
    }
    if (!mounted) return;
    workspaceMutateView(() {
      workspacePending = false;
      if (latest?.deleted == true) {
        workspaceError =
            'Сообщение удалено. Ваш черновик сохранён для копирования.';
      } else if (latest != null && latest.revision > workspaceRevision) {
        workspaceRevision = latest.revision;
        workspaceNeedsRefresh = false;
        workspaceNotice = 'Версия обновлена. Проверьте свой текст перед повторным сохранением.';
      } else {
        workspaceError =
            'Не удалось получить новую версию сообщения. Повторите обновление.';
      }
    });
  }
}
