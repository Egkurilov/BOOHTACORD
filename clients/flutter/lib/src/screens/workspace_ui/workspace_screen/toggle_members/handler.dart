import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceToggleMembersBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceToggleMembers() {
    executeWorkspaceScreenStateWorkspaceToggleMembers();
  }
}

extension WorkspaceScreenStateWorkspaceToggleMembersAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceToggleMembers() {
    if (!workspaceShowMobileSidebar && !workspaceShowMembersDrawer) {
      workspaceDrawerReturnFocus = FocusManager.instance.primaryFocus;
    }
    workspaceMutateView(() {
      workspaceShowMembersDrawer = !workspaceShowMembersDrawer;
      workspaceShowMobileSidebar = false;
    });
  }
}
