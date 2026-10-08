import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceRetryBinding
    on WorkspaceConversationStateContext {
  @override
  Future<void> workspaceRetry(ChatMessage message) {
    return executeWorkspaceConversationStateWorkspaceRetry(message);
  }
}

extension WorkspaceConversationStateWorkspaceRetryAction
    on WorkspaceConversationStateContext {
  Future<void> executeWorkspaceConversationStateWorkspaceRetry(
    ChatMessage message,
  ) async {
    final body = workspaceController.text;
    final replyId = workspaceReplyTarget?.id;
    final mentionIds = workspaceMentionUserIds.toSet();
    final attachmentIds = workspaceAttachments.map((item) => item.id).toList();
    final sent = await widget.state.retryTextSend(message.clientMessageId!);
    if (!sent ||
        !mounted ||
        widget.state.selectedChannel?.id != widget.channel.id ||
        body.trim() != message.body ||
        workspaceController.text != body ||
        replyId != message.replyToId ||
        workspaceReplyTarget?.id != replyId ||
        !setEquals(mentionIds, message.mentionUserIds.toSet()) ||
        !setEquals(workspaceMentionUserIds, mentionIds) ||
        !listEquals(
          attachmentIds,
          message.attachments.map((item) => item.id).toList(),
        ) ||
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
