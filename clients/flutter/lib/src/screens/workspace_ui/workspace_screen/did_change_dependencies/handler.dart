import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateDidChangeDependenciesBinding
    on WorkspaceScreenStateContext {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    executeWorkspaceScreenStateDidChangeDependencies();
  }
}

extension WorkspaceScreenStateDidChangeDependenciesAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateDidChangeDependencies() {
    if (workspaceInitialNavigationApplied) return;
    workspaceInitialNavigationApplied = true;
    final mobile =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    workspaceShowMobileSidebar =
        widget.openNavigationInitially && widget.state.user != null && mobile;
  }
}
