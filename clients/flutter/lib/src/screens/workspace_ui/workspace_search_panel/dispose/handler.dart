import '../../../../features/workspace/search/session.dart';
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
    final sessionKey = workspaceSearchSessionKey;
    if (sessionKey != null &&
        workspaceSearchSessionEpoch == state.workspace.searchSessionEpoch) {
      final query = workspaceQuery.text;
      final normalizedQuery = query.trim();
      final canRestoreResults =
          normalizedQuery.isNotEmpty &&
          (workspaceLoading ||
              (workspaceSearched && workspaceActiveQuery == normalizedQuery));
      state.workspace.searchSessions[sessionKey] = WorkspaceSearchSession(
        query: query,
        scope: workspaceScope,
        scrollOffset: canRestoreResults ? workspaceLastScrollOffset : 0,
        shouldSearch: canRestoreResults,
      );
    }
    workspaceSequence++;
    workspaceQuery.removeListener(workspaceQueryChanged);
    workspaceQuery.dispose();
    workspaceScroll.dispose();
  }
}
