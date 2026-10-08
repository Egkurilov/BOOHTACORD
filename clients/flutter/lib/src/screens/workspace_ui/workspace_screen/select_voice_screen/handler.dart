import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceSelectVoiceScreenBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceSelectVoiceScreen(String? identity) {
    executeWorkspaceScreenStateWorkspaceSelectVoiceScreen(identity);
  }
}

extension WorkspaceScreenStateWorkspaceSelectVoiceScreenAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceSelectVoiceScreen(String? identity) {
    unawaited(widget.state.selectRemoteScreenForViewing(identity));
    workspaceMutateView(() {
      workspaceScreenWaitingToRestart = null;
      workspaceScreenSelectionVoiceChannelId = widget.state.voiceChannel?.id;
      workspaceSelectedScreenIdentity = identity;
      if (identity == null || identity.isEmpty) {
        workspacePinnedScreenIdentity = null;
      } else if (workspacePinnedScreenIdentity != null) {
        workspacePinnedScreenIdentity = identity;
      }
    });
  }
}
