import '../centeritem_builder_list_view/handler.dart';
import '../message_reply_swipe/handler.dart';
import '../../../history_date_divider/component.dart';
import '../../../older_history_error_row/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension ConversationHistoryListRenderer on WorkspaceConversationStateContext {
  ListView renderConversationHistoryList(
    bool compact,
    double viewportWidth,
    List<ConversationTimelineEntry> timeline,
    int historyHeaderCount,
    bool hasOlderTextCursor,
    String? olderTextHistoryError,
  ) => ListView.separated(
    key: const ValueKey('text-channel-messages'),
    controller: workspaceScroll,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: compact
        ? const EdgeInsets.fromLTRB(12, 16, 12, 8)
        : EdgeInsets.fromLTRB(
            viewportWidth < GcLayout.mediumBreakpoint ? 20 : 24,
            20,
            viewportWidth < GcLayout.mediumBreakpoint ? 20 : 24,
            12,
          ),
    itemCount: timeline.length + historyHeaderCount,
    findItemIndexCallback: (key) {
      final messageKey = workspaceMessageKeys.entries
          .where((entry) => identical(entry.value, key))
          .firstOrNull;
      if (messageKey == null) return null;
      final messageId = messageKey.key.substring(widget.channel.id.length + 1);
      final timelineIndex = timeline.indexWhere(
        (entry) => entry.message?.id == messageId,
      );
      if (timelineIndex < 0) return null;
      return timelineIndex + historyHeaderCount;
    },
    separatorBuilder: (context, index) {
      if (index < historyHeaderCount) {
        return const SizedBox(height: 12);
      }
      final timelineIndex = index - historyHeaderCount;
      final current = timeline[timelineIndex];
      final next = timeline[timelineIndex + 1];
      if (current.message == null) {
        return const SizedBox(height: 12);
      }
      if (next.message != null && next.grouped) {
        return const SizedBox(height: 4);
      }
      final attachmentGap =
          next.message != null && current.message!.attachments.isNotEmpty;
      return SizedBox(
        height: attachmentGap
            ? compact
                  ? 25
                  : 34
            : compact
            ? 20
            : 24,
      );
    },
    itemBuilder: (context, index) {
      if (hasOlderTextCursor && index == 0) {
        return renderConversationCenteritemBuilderListView();
      }
      final errorRowIndex = hasOlderTextCursor ? 1 : 0;
      if (olderTextHistoryError != null && index == errorRowIndex) {
        return WorkspaceOlderHistoryErrorRow(
          message: olderTextHistoryError,
          loading: widget.state.loadingOlderMessages,
          onRetry: workspaceLoadOlder,
        );
      }
      final timelineIndex = index - historyHeaderCount;
      final entry = timeline[timelineIndex];
      if (entry.message == null) {
        return WorkspaceHistoryDateDivider(label: entry.dateLabel!);
      }
      final message = entry.message!;
      final key = '${widget.channel.id}:${message.id}';
      return renderConversationMessageReplySwipe(key, context, message, entry);
    },
  );
}
