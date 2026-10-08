import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceSetShortcutForegroundBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceSetShortcutForeground(bool foreground) {
    executeWorkspaceScreenStateWorkspaceSetShortcutForeground(foreground);
  }
}

extension WorkspaceScreenStateWorkspaceSetShortcutForegroundAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceSetShortcutForeground(
    bool foreground,
  ) {
    workspaceShortcutAvailability.setForeground(
      foreground,
      mobile: widget.state.usesTouchPushToTalk,
    );
    if (!foreground) {
      workspaceMutateView(() {
        workspaceCapturingVoiceShortcut = null;
        workspaceCapturingPttKey = false;
      });
      widget.state.voice.cancelVoiceShortcuts();
    }
  }
}
