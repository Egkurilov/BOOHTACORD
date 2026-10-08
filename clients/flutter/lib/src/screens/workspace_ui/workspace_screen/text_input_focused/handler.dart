import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceTextInputFocusedBinding
    on WorkspaceScreenStateContext {
  @override
  bool get workspaceTextInputFocused {
    return executeWorkspaceScreenStateWorkspaceTextInputFocused();
  }
}

extension WorkspaceScreenStateWorkspaceTextInputFocusedAction
    on WorkspaceScreenStateContext {
  bool executeWorkspaceScreenStateWorkspaceTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus?.context;
    return focus?.widget is EditableText ||
        focus?.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
