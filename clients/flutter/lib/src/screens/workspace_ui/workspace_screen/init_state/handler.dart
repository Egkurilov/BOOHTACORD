import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateInitStateBinding on WorkspaceScreenStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceScreenStateInitState();
  }
}

extension WorkspaceScreenStateInitStateAction on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateInitState() {
    workspaceShortcutAccount = widget.state.user?.accountId;
    workspaceLastObservedScreenSharePhase = widget.state.screenSharePhase;
    workspaceLastWorkspacePanel = widget.state.workspacePanel;
    widget.state.addListener(workspaceWorkspaceChanged);
    HardwareKeyboard.instance.addHandler(workspaceHandleHardwareKey);
    WidgetsBinding.instance.addObserver(this);
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      windowManager.addListener(this);
    }
  }
}
