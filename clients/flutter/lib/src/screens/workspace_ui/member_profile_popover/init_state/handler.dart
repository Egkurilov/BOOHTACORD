import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMemberProfilePopoverStateInitStateBinding
    on WorkspaceMemberProfilePopoverStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceMemberProfilePopoverStateInitState();
  }
}

extension WorkspaceMemberProfilePopoverStateInitStateAction
    on WorkspaceMemberProfilePopoverStateContext {
  void executeWorkspaceMemberProfilePopoverStateInitState() {
    unawaited(workspaceLoad());
  }
}
