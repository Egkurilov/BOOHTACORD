import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateDisposeBinding
    on WorkspaceConversationStateContext {
  @override
  void dispose() {
    executeWorkspaceConversationStateDispose();
    super.dispose();
  }
}

extension WorkspaceConversationStateDisposeAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateDispose() {
    workspaceRememberDraft();
    workspaceController.removeListener(workspaceRememberDraft);
    WidgetsBinding.instance.removeObserver(this);
    workspaceController.dispose();
    workspaceComposerFocus.dispose();
    workspaceScroll.dispose();
  }
}
