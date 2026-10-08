import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceWorkspaceSearchPanelStateStateBinding
    on WorkspaceWorkspaceSearchPanelStateContext {
  @override
  AppState get state {
    return executeWorkspaceWorkspaceSearchPanelStateState();
  }
}

extension WorkspaceWorkspaceSearchPanelStateStateAction
    on WorkspaceWorkspaceSearchPanelStateContext {
  AppState executeWorkspaceWorkspaceSearchPanelStateState() => widget.state;
}
