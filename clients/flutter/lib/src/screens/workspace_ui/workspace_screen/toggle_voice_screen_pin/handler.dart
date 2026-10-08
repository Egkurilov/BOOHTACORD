import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceToggleVoiceScreenPinBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceToggleVoiceScreenPin(String? identity) {
    executeWorkspaceScreenStateWorkspaceToggleVoiceScreenPin(identity);
  }
}

extension WorkspaceScreenStateWorkspaceToggleVoiceScreenPinAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceToggleVoiceScreenPin(
    String? identity,
  ) {
    if (identity == null) return;
    unawaited(widget.state.selectRemoteScreenForViewing(identity));
    workspaceMutateView(() {
      workspaceScreenWaitingToRestart = null;
      workspaceScreenSelectionVoiceChannelId = widget.state.voiceChannel?.id;
      workspacePinnedScreenIdentity = workspacePinnedScreenIdentity == identity
          ? null
          : identity;
      workspaceSelectedScreenIdentity = identity;
    });
  }
}
