import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceVisiblePinnedScreenIdentityBinding
    on WorkspaceScreenStateContext {
  @override
  String? get workspaceVisiblePinnedScreenIdentity {
    return executeWorkspaceScreenStateWorkspaceVisiblePinnedScreenIdentity();
  }
}

extension WorkspaceScreenStateWorkspaceVisiblePinnedScreenIdentityAction
    on WorkspaceScreenStateContext {
  String? executeWorkspaceScreenStateWorkspaceVisiblePinnedScreenIdentity() =>
      widget.state.selectedChannel?.id == widget.state.voiceChannel?.id
      ? workspacePinnedScreenIdentity
      : null;
}
