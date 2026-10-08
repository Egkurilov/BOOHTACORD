import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceAudioActivationSelectorStateDisposeBinding
    on WorkspaceAudioActivationSelectorStateContext {
  @override
  void dispose() {
    executeWorkspaceAudioActivationSelectorStateDispose();
    super.dispose();
  }
}

extension WorkspaceAudioActivationSelectorStateDisposeAction
    on WorkspaceAudioActivationSelectorStateContext {
  void executeWorkspaceAudioActivationSelectorStateDispose() {
    workspaceVoiceFocusNode.dispose();
    workspacePushToTalkFocusNode.dispose();
  }
}
