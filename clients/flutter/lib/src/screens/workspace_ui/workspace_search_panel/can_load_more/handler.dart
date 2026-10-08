import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateWorkspaceCanLoadMoreBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  bool get workspaceCanLoadMore {
    return executeWorkspaceWorkspaceSearchPanelStateWorkspaceCanLoadMore();
  }
}

extension WorkspaceWorkspaceSearchPanelStateWorkspaceCanLoadMoreAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  bool executeWorkspaceWorkspaceSearchPanelStateWorkspaceCanLoadMore() =>
      workspaceNextCursor != null &&
      !workspaceLoading &&
      workspaceQuery.text.trim() == workspaceActiveQuery;
}
