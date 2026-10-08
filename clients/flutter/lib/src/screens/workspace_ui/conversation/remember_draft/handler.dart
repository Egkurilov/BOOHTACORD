import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceRememberDraftBinding
    on WorkspaceConversationStateContext {
  @override
  void workspaceRememberDraft() {
    executeWorkspaceConversationStateWorkspaceRememberDraft();
  }
}

extension WorkspaceConversationStateWorkspaceRememberDraftAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateWorkspaceRememberDraft() {
    final accountId = workspaceDraftAccountId;
    if (workspaceRestoringDraft ||
        accountId == null ||
        workspaceDraftEpoch != ComposerDraftMemory.epoch) {
      return;
    }
    ComposerDraftMemory.save(
      accountId,
      ComposerDraftKind.channel,
      widget.channel.id,
      ComposerDraft<ChatMessage>(
        body: workspaceController.text,
        replyTarget: workspaceReplyTarget,
        attachments: workspaceAttachments,
        mentionUserIds: workspaceMentionUserIds.toList(growable: false),
      ),
    );
  }
}
