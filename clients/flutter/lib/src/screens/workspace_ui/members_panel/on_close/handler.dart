import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateOnCloseBinding
    on WorkspaceMembersPanelStateContext {
  @override
  VoidCallback? get onClose {
    return executeWorkspaceMembersPanelStateOnClose();
  }
}

extension WorkspaceMembersPanelStateOnCloseAction
    on WorkspaceMembersPanelStateContext {
  VoidCallback? executeWorkspaceMembersPanelStateOnClose() => widget.onClose;
}
