import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateInitStateBinding
    on WorkspaceConversationStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceConversationStateInitState();
  }
}

extension WorkspaceConversationStateInitStateAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateInitState() {
    workspaceDraftAccountId = widget.state.user?.accountId;
    workspaceDraftEpoch = ComposerDraftMemory.epoch;
    workspaceController.addListener(workspaceRememberDraft);
    workspaceRestoreDraft(widget.channel.id);
    WidgetsBinding.instance.addObserver(this);
    workspaceScroll.addListener(workspaceOnScroll);
  }
}
