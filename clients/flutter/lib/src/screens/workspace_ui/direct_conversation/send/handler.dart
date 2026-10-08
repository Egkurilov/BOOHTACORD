import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceSendBinding
    on WorkspaceDirectConversationStateContext {
  @override
  Future<void> workspaceSend() {
    return executeWorkspaceDirectConversationStateWorkspaceSend();
  }
}

extension WorkspaceDirectConversationStateWorkspaceSendAction
    on WorkspaceDirectConversationStateContext {
  Future<void> executeWorkspaceDirectConversationStateWorkspaceSend() async {
    if (widget.state.sending || workspaceAttachmentsPending) return;
    final body = workspaceController.text;
    final replyId = workspaceReplyTarget?.id;
    final mentionIds = workspaceMentionUserIds.toSet();
    final attachmentIds = workspaceAttachments.map((item) => item.id).toList();
    final sent = await widget.state.sendDirect(
      body,
      replyToId: replyId,
      mentionUserIds: workspaceMentionUserIds.toList(),
      attachments: workspaceAttachments,
    );
    if (!sent ||
        !mounted ||
        widget.state.selectedDirectMessage?.id != widget.conversation.id) {
      return;
    }
    if (workspaceController.text != body ||
        workspaceReplyTarget?.id != replyId ||
        !setEquals(workspaceMentionUserIds, mentionIds) ||
        !listEquals(
          workspaceAttachments.map((item) => item.id).toList(),
          attachmentIds,
        )) {
      return;
    }
    workspaceController.clear();
    workspaceMutateView(() {
      workspaceReplyTarget = null;
      workspaceMentionUserIds.clear();
      workspaceAttachments = const [];
    });
    workspaceRememberDraft();
  }
}
