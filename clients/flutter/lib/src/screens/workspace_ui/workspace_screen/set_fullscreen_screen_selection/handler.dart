import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceSetFullscreenScreenSelectionBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceSetFullscreenScreenSelection(
    ScreenFullscreenSelection? selection,
  ) {
    executeWorkspaceScreenStateWorkspaceSetFullscreenScreenSelection(selection);
  }
}

extension WorkspaceScreenStateWorkspaceSetFullscreenScreenSelectionAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceSetFullscreenScreenSelection(
    ScreenFullscreenSelection? selection,
  ) {
    if (!mounted ||
        (workspaceFullscreenScreenSelection == null && selection == null) ||
        (workspaceFullscreenScreenSelection != null &&
            selection != null &&
            workspaceFullscreenScreenSelection!.identity ==
                selection.identity &&
            workspaceFullscreenScreenSelection!.generation ==
                selection.generation)) {
      return;
    }
    workspaceMutateView(() => workspaceFullscreenScreenSelection = selection);
  }
}
