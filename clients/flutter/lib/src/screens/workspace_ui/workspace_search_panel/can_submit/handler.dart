import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateWorkspaceCanSubmitBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  bool get workspaceCanSubmit {
    return executeWorkspaceWorkspaceSearchPanelStateWorkspaceCanSubmit();
  }
}

extension WorkspaceWorkspaceSearchPanelStateWorkspaceCanSubmitAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  bool executeWorkspaceWorkspaceSearchPanelStateWorkspaceCanSubmit() =>
      !workspaceLoading &&
      workspaceQuery.text.trim().isNotEmpty &&
      !(workspaceScope == 'current' && workspaceCurrentConversation() == null);
}
