import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceHandleSearchShortcutBinding
    on WorkspaceScreenStateContext {
  @override
  bool workspaceHandleSearchShortcut() {
    return executeWorkspaceScreenStateWorkspaceHandleSearchShortcut();
  }
}

extension WorkspaceScreenStateWorkspaceHandleSearchShortcutAction
    on WorkspaceScreenStateContext {
  bool executeWorkspaceScreenStateWorkspaceHandleSearchShortcut() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        (focusContext.widget is EditableText ||
            focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return false;
    }
    workspaceToggleSearch();
    return true;
  }
}
