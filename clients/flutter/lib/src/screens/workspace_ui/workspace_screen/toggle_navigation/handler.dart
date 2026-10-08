import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceToggleNavigationBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceToggleNavigation() {
    executeWorkspaceScreenStateWorkspaceToggleNavigation();
  }
}

extension WorkspaceScreenStateWorkspaceToggleNavigationAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceToggleNavigation() {
    if (!workspaceShowMobileSidebar && !workspaceShowMembersDrawer) {
      workspaceDrawerReturnFocus = FocusManager.instance.primaryFocus;
    }
    workspaceMutateView(() {
      workspaceShowMobileSidebar = !workspaceShowMobileSidebar;
      workspaceShowMembersDrawer = false;
    });
  }
}
