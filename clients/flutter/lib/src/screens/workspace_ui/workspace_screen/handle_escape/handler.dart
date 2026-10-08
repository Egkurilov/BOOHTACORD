import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceHandleEscapeBinding
    on WorkspaceScreenStateContext {
  @override
  bool workspaceHandleEscape() {
    return executeWorkspaceScreenStateWorkspaceHandleEscape();
  }
}

extension WorkspaceScreenStateWorkspaceHandleEscapeAction
    on WorkspaceScreenStateContext {
  bool executeWorkspaceScreenStateWorkspaceHandleEscape() {
    if (workspaceShowMobileSidebar || workspaceShowMembersDrawer) {
      workspaceCloseDrawers();
      return true;
    } else if (widget.state.workspacePanel == WorkspacePanel.search ||
        widget.state.workspacePanel == WorkspacePanel.searchContext) {
      widget.state.closeSearchPanel();
      return true;
    }
    return false;
  }
}
