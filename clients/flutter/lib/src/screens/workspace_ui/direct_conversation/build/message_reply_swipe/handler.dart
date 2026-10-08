import '../message_bubble/handler.dart';
import '../../../direct_message_action_menu/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension DirectConversationMessageReplySwipeRenderer
    on WorkspaceDirectConversationStateContext {
  KeyedSubtree renderDirectConversationMessageReplySwipe(
    GlobalKey<State<StatefulWidget>> key,
    BuildContext context,
    DirectChatMessage message,
    bool own,
  ) => KeyedSubtree(
    key: key,
    child: HorizontalSwipeRegion(
      enabled:
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android) &&
          MediaQuery.sizeOf(context).width < 1024 &&
          !message.deleted &&
          message.sendStatus == null,
      canStart: (position, _) => position.dx >= 72,
      onSwipeRight: () => workspaceReplyToDirect(message),
      child: Row(
        mainAxisAlignment: own
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          renderDirectConversationMessageBubble(own, message),
          if (!message.deleted && message.sendStatus == null)
            WorkspaceDirectMessageActionMenu(
              message: message,
              canEdit: own,
              onReply: workspaceReplyToDirect,
              mentionOptions: [
                (
                  widget.conversation.participantId,
                  widget.conversation.displayName,
                ),
              ],
              selfId: widget.state.user?.accountId ?? '',
              onEdit: (body, revision, ids) =>
                  widget.state.editDirectWithResult(
                    message,
                    body,
                    revision,
                    mentionUserIds: ids,
                  ),
              onRefresh: () async {
                final latest = await widget.state.refreshDirectMessageRevision(
                  message,
                );
                return latest == null
                    ? null
                    : (revision: latest.revision, deleted: latest.deleted);
              },
              onDelete: () => widget.state.deleteDirect(message),
            ),
        ],
      ),
    ),
  );
}
