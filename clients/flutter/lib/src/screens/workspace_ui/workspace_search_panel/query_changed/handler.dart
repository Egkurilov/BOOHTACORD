import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateWorkspaceQueryChangedBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  void workspaceQueryChanged() {
    executeWorkspaceWorkspaceSearchPanelStateWorkspaceQueryChanged();
  }
}

extension WorkspaceWorkspaceSearchPanelStateWorkspaceQueryChangedAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  void executeWorkspaceWorkspaceSearchPanelStateWorkspaceQueryChanged() {
    if (mounted) workspaceMutateView(() {});
  }
}
