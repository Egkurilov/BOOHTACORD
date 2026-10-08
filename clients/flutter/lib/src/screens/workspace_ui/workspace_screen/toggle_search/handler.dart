import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceToggleSearchBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceToggleSearch() {
    executeWorkspaceScreenStateWorkspaceToggleSearch();
  }
}

extension WorkspaceScreenStateWorkspaceToggleSearchAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceToggleSearch() {
    if (widget.state.workspacePanel == WorkspacePanel.search ||
        widget.state.workspacePanel == WorkspacePanel.searchContext) {
      widget.state.closeSearchPanel();
    } else {
      widget.state.openSearchPanel();
      workspaceCloseDrawers();
    }
  }
}
