import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceCategoryStateWorkspaceShowObjectMenuBinding
    on WorkspaceCategoryStateContext {
  @override
  bool get workspaceShowObjectMenu {
    return executeWorkspaceCategoryStateWorkspaceShowObjectMenu();
  }
}

extension WorkspaceCategoryStateWorkspaceShowObjectMenuAction
    on WorkspaceCategoryStateContext {
  bool executeWorkspaceCategoryStateWorkspaceShowObjectMenu() =>
      workspaceHovered || workspaceFocused;
}
