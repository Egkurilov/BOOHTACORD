import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateWorkspaceQueryChangedBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  void workspaceQueryChanged() {
    final normalizedQuery = workspaceQuery.text.trim();
    if (normalizedQuery != workspaceActiveQuery) {
      workspaceRestoreScrollOffset = 0;
      workspaceLastScrollOffset = 0;
    }
    executeWorkspaceWorkspaceSearchPanelStateWorkspaceQueryChanged();
  }
}

extension WorkspaceWorkspaceSearchPanelStateWorkspaceQueryChangedAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  void executeWorkspaceWorkspaceSearchPanelStateWorkspaceQueryChanged() {
    if (mounted) {
      workspaceMutateView(() {});
      workspaceSaveSearchSession();
    }
  }
}
