import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateOnWindowFocusBinding on WorkspaceScreenStateContext {
  @override
  void onWindowFocus() {
    executeWorkspaceScreenStateOnWindowFocus();
  }
}

extension WorkspaceScreenStateOnWindowFocusAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateOnWindowFocus() {
    widget.state.voice.setRemoteScreenViewerForeground(true);
    workspaceSetShortcutForeground(true);
    widget.state.setNotificationAppForeground(true);
    unawaited(widget.state.refreshNotificationStatus());
  }
}
