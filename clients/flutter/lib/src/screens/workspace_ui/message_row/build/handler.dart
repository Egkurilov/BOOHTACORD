import 'sender_metadata/handler.dart';
import 'sender_header/handler.dart';
import '../../confirm_delete/component.dart';
import '../../mention_display_name/component.dart';
import '../../reply_preview/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMessageRowBuildBinding on WorkspaceMessageRowContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceMessageRowBuild(context);
  }
}

extension WorkspaceMessageRowBuildAction on WorkspaceMessageRowContext {
  Widget executeWorkspaceMessageRowBuild(BuildContext context) {
    observeMessageRender(message, context);
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    final avatarDiameter = compact ? 32.0 : 36.0;
    final member = state.members
        .where((value) => value.id == message.authorId)
        .firstOrNull;
    final authorName = member?.displayName ?? message.authorId;
    if (message.kind == 'SYSTEM_WELCOME') {
      return SystemWelcomeMessage(
        message: message,
        displayName: member?.displayName ?? 'Участник',
        onDelete: state.user?.isAdmin == true
            ? () async {
                if (await workspaceConfirmDelete(context)) {
                  await state.deleteText(message);
                }
              }
            : null,
      );
    }
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grouped)
          SizedBox(width: avatarDiameter, height: 0)
        else
          AuthenticatedAvatar(
            state: state,
            name: authorName,
            avatarUrl: member?.avatarUrl,
            radius: avatarDiameter / 2,
            backgroundColor: GcColors.accent,
          ),
        SizedBox(width: compact ? 8 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!grouped)
                renderMessageRowSenderHeader(authorName, time)
              else
                renderMessageRowSenderMetadata(authorName, time),
              if (!grouped) const SizedBox(height: 4),
              if (replyPreview != null && !message.deleted)
                WorkspaceReplyPreview(
                  label: replyPreview!,
                  onTap: onJumpToReply,
                ),
              if (message.deleted)
                const Text(
                  'Сообщение удалено',
                  style: TextStyle(
                    color: GcColors.muted,
                    fontSize: 15,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                FormattedMessageBody(body: message.body, color: GcColors.text),
              DeliveryStatus(
                status: message.sendStatus,
                busy: state.sending,
                retryBlocked: state.conversation.blockedSendRetries.contains(
                  message.clientMessageId,
                ),
                onRetry: onRetry,
                onDiscard: () => state.deleteText(message),
              ),
              if (!message.deleted &&
                  message.sendStatus == null &&
                  message.attachments.isNotEmpty)
                MessageAttachmentList(
                  state: state,
                  parentPath:
                      '/channels/${Uri.encodeComponent(message.channelId)}',
                  attachments: message.attachments,
                ),
              if (message.mentionUserIds.isNotEmpty && !message.deleted)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'Упомянуты: ${message.mentionUserIds.map((id) => workspaceMentionDisplayName(state, id)).join(' ')}',
                    style: const TextStyle(color: GcColors.muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
