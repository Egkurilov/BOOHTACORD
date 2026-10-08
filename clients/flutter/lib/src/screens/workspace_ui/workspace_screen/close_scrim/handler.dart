import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceCloseScrimBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceCloseScrim() {
    executeWorkspaceScreenStateWorkspaceCloseScrim();
  }
}

extension WorkspaceScreenStateWorkspaceCloseScrimAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceCloseScrim() {
    workspaceCloseDrawers();
    if (widget.state.workspacePanel == WorkspacePanel.search) {
      widget.state.closeSearchPanel();
    }
  }
}
