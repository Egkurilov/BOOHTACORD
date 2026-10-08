import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceCloseDrawersBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceCloseDrawers() {
    executeWorkspaceScreenStateWorkspaceCloseDrawers();
  }
}

extension WorkspaceScreenStateWorkspaceCloseDrawersAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceCloseDrawers() {
    if (!workspaceShowMobileSidebar && !workspaceShowMembersDrawer) return;
    final returnFocus = workspaceDrawerReturnFocus;
    final restoreFocus = widget.state.workspacePanel == WorkspacePanel.none;
    workspaceDrawerReturnFocus = null;
    workspaceMutateView(() {
      workspaceShowMobileSidebar = false;
      workspaceShowMembersDrawer = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !restoreFocus ||
          returnFocus?.context == null ||
          !returnFocus!.canRequestFocus) {
        return;
      }
      returnFocus.requestFocus();
    });
  }
}
