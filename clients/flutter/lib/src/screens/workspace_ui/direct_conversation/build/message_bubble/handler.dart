import '../../../mention_display_name/component.dart';
import '../../../reply_preview/component.dart';
import '../../../native_bindings.dart';
import '../../../message_social/component.dart';
import '../../lifecycle/context.dart';

extension DirectConversationMessageBubbleRenderer
    on WorkspaceDirectConversationStateContext {
  Flexible renderDirectConversationMessageBubble(
    bool own,
    DirectChatMessage message,
  ) => Flexible(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 560),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: own ? GcColors.selected : GcColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (workspaceDirectReplyLabel(message) case final label?)
            WorkspaceReplyPreview(
              label: label,
              onTap: () => workspaceJumpToDirectReply(message),
            ),
          if (message.deleted)
            const Text(
              'Сообщение удалено',
              style: TextStyle(
                color: GcColors.muted,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            FormattedMessageBody(
              body: message.body,
              color: GcColors.text,
              fontSize: 14,
              lineHeight: 1.4,
            ),
          DeliveryStatus(
            status: message.sendStatus,
            busy: widget.state.sending,
            retryBlocked: widget.state.conversation.blockedSendRetries.contains(
              message.clientMessageId,
            ),
            onRetry: () => workspaceRetry(message),
            onDiscard: () => widget.state.deleteDirect(message),
          ),
          if (!message.deleted &&
              message.sendStatus == null &&
              message.attachments.isNotEmpty)
            MessageAttachmentList(
              state: widget.state,
              parentPath:
                  '/direct-messages/${Uri.encodeComponent(message.directMessageId)}',
              attachments: message.attachments,
            ),
          if (message.mentionUserIds.isNotEmpty && !message.deleted) ...[
            const SizedBox(height: 5),
            Text(
              'Упомянуты: ${message.mentionUserIds.map((id) => workspaceMentionDisplayName(widget.state, id)).join(' ')}',
              style: const TextStyle(color: GcColors.muted, fontSize: 11),
            ),
          ],
          if (!message.deleted && message.sendStatus == null)
            MessageSocialControls(
              transport: widget.state.api.transport,
              direct: true,
              conversation: message.directMessageId,
              message: message.id,
            ),
        ],
      ),
    ),
  );
}
