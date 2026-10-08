import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateDisposeBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  void dispose() {
    executeWorkspaceWorkspaceSearchPanelStateDispose();
    super.dispose();
  }
}

extension WorkspaceWorkspaceSearchPanelStateDisposeAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  void executeWorkspaceWorkspaceSearchPanelStateDispose() {
    workspaceSequence++;
    workspaceQuery.removeListener(workspaceQueryChanged);
    workspaceQuery.dispose();
    workspaceScroll.dispose();
  }
}
