import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateStateBinding
    on WorkspaceMembersPanelStateContext {
  @override
  AppState get state {
    return executeWorkspaceMembersPanelStateState();
  }
}

extension WorkspaceMembersPanelStateStateAction
    on WorkspaceMembersPanelStateContext {
  AppState executeWorkspaceMembersPanelStateState() => widget.state;
}
