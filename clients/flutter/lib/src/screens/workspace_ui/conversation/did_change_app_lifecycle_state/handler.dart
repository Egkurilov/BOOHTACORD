import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateDidChangeAppLifecycleStateBinding
    on WorkspaceConversationStateContext {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    executeWorkspaceConversationStateDidChangeAppLifecycleState(state);
  }
}

extension WorkspaceConversationStateDidChangeAppLifecycleStateAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateDidChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      workspaceScheduleVisibleRead(widget.state.messages);
    }
  }
}
