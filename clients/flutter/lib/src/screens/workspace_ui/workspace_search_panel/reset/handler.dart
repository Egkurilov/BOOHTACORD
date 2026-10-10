import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateWorkspaceResetBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  void workspaceReset() {
    executeWorkspaceWorkspaceSearchPanelStateWorkspaceReset();
  }
}

extension WorkspaceWorkspaceSearchPanelStateWorkspaceResetAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  void executeWorkspaceWorkspaceSearchPanelStateWorkspaceReset() {
    workspaceSequence++;
    workspaceResults = const [];
    workspaceNextCursor = null;
    workspaceActiveQuery = '';
    workspaceError = null;
    workspaceLoading = false;
    workspaceSearched = false;
    workspaceRestoreScrollOffset = 0;
    workspaceLastScrollOffset = 0;
    workspaceSaveSearchSession();
  }
}
