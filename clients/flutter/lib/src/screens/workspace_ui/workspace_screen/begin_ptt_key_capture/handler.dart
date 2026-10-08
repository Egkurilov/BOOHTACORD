import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceBeginPttKeyCaptureBinding
    on WorkspaceScreenStateContext {
  @override
  void workspaceBeginPttKeyCapture() {
    executeWorkspaceScreenStateWorkspaceBeginPttKeyCapture();
  }
}

extension WorkspaceScreenStateWorkspaceBeginPttKeyCaptureAction
    on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateWorkspaceBeginPttKeyCapture() =>
      workspaceMutateView(() => workspaceCapturingPttKey = true);
}
