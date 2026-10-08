import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceSendBinding
    on WorkspaceConversationStateContext {
  @override
  Future<void> workspaceSend() {
    return executeWorkspaceConversationStateWorkspaceSend();
  }
}

extension WorkspaceConversationStateWorkspaceSendAction
    on WorkspaceConversationStateContext {
  Future<void> executeWorkspaceConversationStateWorkspaceSend() async {
    if (workspaceAttachmentsPending) return;
    final body = workspaceController.text;
    final replyId = workspaceReplyTarget?.id;
    final mentionIds = workspaceMentionUserIds.toSet();
    final attachmentIds = workspaceAttachments.map((item) => item.id).toList();
    final sent = await widget.state.send(
      body,
      replyToId: replyId,
      mentionUserIds: workspaceMentionUserIds.toList(),
      attachments: workspaceAttachments,
    );
    if (!sent ||
        !mounted ||
        widget.state.selectedChannel?.id != widget.channel.id) {
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
    workspaceFollowLatest = true;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (mounted && workspaceScroll.hasClients) {
      await workspaceScroll.animateTo(
        workspaceScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }
}
