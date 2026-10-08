import '../../../message_row/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension ConversationMessageReplySwipeRenderer
    on WorkspaceConversationStateContext {
  KeyedSubtree renderConversationMessageReplySwipe(
    String key,
    BuildContext context,
    ChatMessage message,
    ConversationTimelineEntry entry,
  ) => KeyedSubtree(
    key: workspaceMessageKeys.putIfAbsent(
      key,
      () => GlobalKey(debugLabel: key),
    ),
    child: HorizontalSwipeRegion(
      enabled:
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android) &&
          MediaQuery.sizeOf(context).width < 1024 &&
          !message.deleted &&
          message.sendStatus == null,
      canStart: (position, _) => position.dx >= 72,
      onSwipeRight: () => workspaceReplyTo(message),
      child: WorkspaceMessageRow(
        state: widget.state,
        message: message,
        grouped: entry.grouped,
        replyPreview: workspaceReplyPreview(message),
        onReply: workspaceReplyTo,
        onJumpToReply: () => workspaceJumpToReply(message),
        onRetry: message.clientMessageId == null
            ? null
            : () => workspaceRetry(message),
      ),
    ),
  );
}
