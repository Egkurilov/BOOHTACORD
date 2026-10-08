import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceDirectConversationStateWorkspaceVisibleDirectMessageAnchorsBinding
    on WorkspaceDirectConversationStateContext {
  @override
  List<({GlobalKey key, double top})> workspaceVisibleDirectMessageAnchors() {
    return executeWorkspaceDirectConversationStateWorkspaceVisibleDirectMessageAnchors();
  }
}

extension WorkspaceDirectConversationStateWorkspaceVisibleDirectMessageAnchorsAction
    on WorkspaceDirectConversationStateContext {
  List<({GlobalKey key, double top})>
  executeWorkspaceDirectConversationStateWorkspaceVisibleDirectMessageAnchors() {
    if (!workspaceScroll.hasClients) return const [];
    final anchors = <({GlobalKey key, double top})>[];
    for (final message in widget.state.directMessageHistory) {
      final key =
          workspaceDirectMessageKeys['${widget.conversation.id}:${message.id}'];
      final row = key?.currentContext?.findRenderObject();
      if (row is! RenderBox || !row.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(row);
      if (viewport is! RenderBox) continue;
      final rowRect = row.localToGlobal(Offset.zero) & row.size;
      final viewportBox = viewport as RenderBox;
      final viewportRect =
          viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
      if (rowRect.bottom > viewportRect.top &&
          rowRect.top < viewportRect.bottom &&
          rowRect.right > viewportRect.left &&
          rowRect.left < viewportRect.right) {
        anchors.add((key: key!, top: rowRect.top));
      }
    }
    return anchors;
  }
}
