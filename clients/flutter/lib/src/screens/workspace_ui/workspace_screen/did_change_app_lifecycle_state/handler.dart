import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateDidChangeAppLifecycleStateBinding
    on WorkspaceScreenStateContext {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    executeWorkspaceScreenStateDidChangeAppLifecycleState(state);
  }
}

extension WorkspaceScreenStateDidChangeAppLifecycleStateAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateDidChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    widget.state.voice.setRemoteScreenViewerForeground(
      state == AppLifecycleState.resumed,
    );
    workspaceSetShortcutForeground(state == AppLifecycleState.resumed);
    widget.state.setNotificationAppForeground(
      state == AppLifecycleState.resumed,
    );
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.state.setPushToTalkPressed(false));
    } else {
      unawaited(widget.state.refreshNotificationStatus());
    }
  }
}
