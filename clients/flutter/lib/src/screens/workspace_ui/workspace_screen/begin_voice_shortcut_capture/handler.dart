import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceBeginVoiceShortcutCaptureBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceBeginVoiceShortcutCapture(String action) {
    executeWorkspaceScreenStateWorkspaceBeginVoiceShortcutCapture(action);
  }
}

extension WorkspaceScreenStateWorkspaceBeginVoiceShortcutCaptureAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceBeginVoiceShortcutCapture(
    String action,
  ) => workspaceMutateView(() {
    workspaceCapturingPttKey = false;
    workspaceCapturingVoiceShortcut = action.isEmpty ? null : action;
  });
}
