import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateOnWindowBlurBinding on WorkspaceScreenStateContext {
  @override
  void onWindowBlur() {
    executeWorkspaceScreenStateOnWindowBlur();
  }
}

extension WorkspaceScreenStateOnWindowBlurAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateOnWindowBlur() {
    widget.state.voice.setRemoteScreenViewerForeground(false);
    workspaceSetShortcutForeground(false);
    widget.state.setNotificationAppForeground(false);
    unawaited(widget.state.setPushToTalkPressed(false));
  }
}
