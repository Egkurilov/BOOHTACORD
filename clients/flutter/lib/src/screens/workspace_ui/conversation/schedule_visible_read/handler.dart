import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceConversationStateWorkspaceScheduleVisibleReadBinding
    on WorkspaceConversationStateContext {
  @override
  void workspaceScheduleVisibleRead(
    List<ChatMessage> renderedMessages, {
    bool correctLatestLayout = false,
  }) {
    executeWorkspaceConversationStateWorkspaceScheduleVisibleRead(
      renderedMessages,
      correctLatestLayout: correctLatestLayout,
    );
  }
}

extension WorkspaceConversationStateWorkspaceScheduleVisibleReadAction
    on WorkspaceConversationStateContext {
  void executeWorkspaceConversationStateWorkspaceScheduleVisibleRead(
    List<ChatMessage> renderedMessages, {
    bool correctLatestLayout = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.state.loadingMessages ||
          widget.state.selectedChannel?.id != widget.channel.id ||
          !identical(widget.state.messages, renderedMessages) ||
          !workspaceScroll.hasClients) {
        return;
      }
      final restoreOffset = workspaceRestoreScrollOffset;
      if (restoreOffset != null && !workspaceFollowLatest) {
        final position = workspaceScroll.position;
        final target = restoreOffset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        workspaceRestoreScrollOffset = null;
        if ((position.pixels - target).abs() > 0.5) {
          position.jumpTo(target);
        }
        workspaceRememberScrollPosition();
        workspaceScheduleVisibleRead(
          renderedMessages,
          correctLatestLayout: correctLatestLayout,
        );
        return;
      }
      if (correctLatestLayout &&
          workspaceFollowLatest &&
          workspaceScroll.position.extentAfter > 1) {
        workspaceScroll.jumpTo(workspaceScroll.position.maxScrollExtent);
        workspaceScheduleVisibleRead(
          renderedMessages,
          correctLatestLayout: true,
        );
        return;
      }
      if (correctLatestLayout &&
          workspaceFollowLatest &&
          !workspaceLatestLayoutConfirmed) {
        workspaceLatestLayoutConfirmed = true;
        workspaceScheduleVisibleRead(
          renderedMessages,
          correctLatestLayout: true,
        );
        return;
      }
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final visibleMessages = <ChatMessage>[];
      for (final message in renderedMessages) {
        if (message.sendStatus != null) continue;
        final row = workspaceMessageKeys['${widget.channel.id}:${message.id}']
            ?.currentContext
            ?.findRenderObject();
        if (row is! RenderBox || !row.attached) continue;
        final candidateViewport = RenderAbstractViewport.maybeOf(row);
        if (candidateViewport is! RenderBox) continue;
        final viewportBox = candidateViewport as RenderBox;
        final rowRect = row.localToGlobal(Offset.zero) & row.size;
        final viewportRect =
            viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
        if (rowRect.bottom > viewportRect.top &&
            rowRect.top < viewportRect.bottom &&
            rowRect.right > viewportRect.left &&
            rowRect.left < viewportRect.right) {
          visibleMessages.add(message);
        }
      }
      final newestVisible = visibleMessages.lastOrNull;
      if (newestVisible != null) {
        unawaited(
          widget.state.markTextChannelRead(widget.channel.id, newestVisible.id),
        );
      }
    });
  }
}
