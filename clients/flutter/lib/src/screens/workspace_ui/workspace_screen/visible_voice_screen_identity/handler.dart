import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceVisibleVoiceScreenIdentityBinding
    on WorkspaceScreenStateContext {
  @override
  String? get workspaceVisibleVoiceScreenIdentity {
    return executeWorkspaceScreenStateWorkspaceVisibleVoiceScreenIdentity();
  }
}

extension WorkspaceScreenStateWorkspaceVisibleVoiceScreenIdentityAction
    on WorkspaceScreenStateContext {
  String? executeWorkspaceScreenStateWorkspaceVisibleVoiceScreenIdentity() =>
      widget.state.selectedChannel?.id == widget.state.voiceChannel?.id
      ? workspaceSelectedScreenIdentity
      : null;
}
