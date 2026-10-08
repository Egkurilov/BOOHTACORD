import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceChannelRowStateWorkspaceShowObjectMenuBinding
    on WorkspaceChannelRowStateContext {
  @override
  bool get workspaceShowObjectMenu {
    return executeWorkspaceChannelRowStateWorkspaceShowObjectMenu();
  }
}

extension WorkspaceChannelRowStateWorkspaceShowObjectMenuAction
    on WorkspaceChannelRowStateContext {
  bool executeWorkspaceChannelRowStateWorkspaceShowObjectMenu() =>
      workspaceHovered || workspaceFocused;
}
