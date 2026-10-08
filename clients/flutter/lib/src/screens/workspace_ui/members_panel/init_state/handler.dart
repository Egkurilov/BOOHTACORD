import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateInitStateBinding
    on WorkspaceMembersPanelStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceMembersPanelStateInitState();
  }
}

extension WorkspaceMembersPanelStateInitStateAction
    on WorkspaceMembersPanelStateContext {
  void executeWorkspaceMembersPanelStateInitState() {
    HardwareKeyboard.instance.addHandler(workspaceHandleHardwareKey);
  }
}
