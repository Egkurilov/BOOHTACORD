import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceStopWatchingPinnedScreenBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceStopWatchingPinnedScreen() {
    executeWorkspaceScreenStateWorkspaceStopWatchingPinnedScreen();
  }
}

extension WorkspaceScreenStateWorkspaceStopWatchingPinnedScreenAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceStopWatchingPinnedScreen() {
    unawaited(widget.state.selectRemoteScreenForViewing(null));
    workspaceMutateView(() {
      workspaceScreenWaitingToRestart = null;
      workspaceScreenSelectionVoiceChannelId = widget.state.voiceChannel?.id;
      workspaceSelectedScreenIdentity = '';
      workspacePinnedScreenIdentity = null;
    });
  }
}
