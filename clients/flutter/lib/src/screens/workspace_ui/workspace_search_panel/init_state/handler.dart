import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateInitStateBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceWorkspaceSearchPanelStateInitState();
  }
}

extension WorkspaceWorkspaceSearchPanelStateInitStateAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  void executeWorkspaceWorkspaceSearchPanelStateInitState() {
    workspaceScope = workspaceCurrentConversation() == null ? 'all' : 'current';
    workspaceQuery.addListener(workspaceQueryChanged);
  }
}
