import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMessageEditDialogStateDisposeBinding
    on WorkspaceMessageEditDialogStateContext {
  @override
  void dispose() {
    executeWorkspaceMessageEditDialogStateDispose();
    super.dispose();
  }
}

extension WorkspaceMessageEditDialogStateDisposeAction
    on WorkspaceMessageEditDialogStateContext {
  void executeWorkspaceMessageEditDialogStateDispose() {
    workspaceController.dispose();
  }
}
